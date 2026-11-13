//
//  LaundromatListInteractor.swift
//  wishywashy
//
//  Nearby laundromats come from Apple Maps; partner laundromats (with machines) come from `PartnerLaundromats`.
//

import CoreLocation
import Foundation

final class LaundromatListInteractor: LaundromatListInteractorInputProtocol {
    weak var output: LaundromatListInteractorOutputProtocol?   // weak avoids a retain cycle

    private let store = LaundromatStore.shared
    private let bookings: BookingService
    private let partnerRadius: CLLocationDistance = 25_000

    private var criteria: SortingCriteria = .distance
    private var query = ""
    private var results: [Laundromat] = []
    private var notice: String?
    private var loadTask: Task<Void, Never>?

    init(bookings: BookingService = Services.bookings) {
        self.bookings = bookings
    }

    func fetchLaundromats() {
        load()
    }

    func searchLocation(_ query: String) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        load()
    }

    func sortLaundromats(by criteria: SortingCriteria) {
        self.criteria = criteria
        publish()
    }

    func selectLaundromat(id: String) {
        guard let laundromat = results.first(where: { $0.id == id }) else { return }
        store.select(laundromat)
        publish()
    }

    func toggleSaved(id: String) {
        guard let laundromat = results.first(where: { $0.id == id }) else { return }
        store.toggleSaved(laundromat)
        publish()
    }

    // MARK: - Loading
    private func load() {
        loadTask?.cancel()
        output?.didStartLoading()
        let query = query
        loadTask = Task { [weak self] in
            guard let self else { return }

            let center: CLLocation?
            var notice: String?
            if query.isEmpty {
                center = await LocationService.shared.currentLocation()
                if center == nil {
                    notice = "Location is off, so only partner laundromats are shown. Search a place to find more."
                }
            } else {
                center = await LaundromatSearchService.locate(query)
                if center == nil {
                    if !Task.isCancelled {
                        output?.didFail(message: "Couldn't find \u{201C}\(query)\u{201D}.\nTry another place or a postal code.")
                    }
                    return
                }
            }

            var found: [Laundromat] = []
            if let center {
                do {
                    found = try await LaundromatSearchService.laundromats(around: center)
                } catch {
                    notice = "Couldn't reach Apple Maps, so only partner laundromats are shown."
                }
            }
            if Task.isCancelled { return }

            self.results = partners(near: center) + found
            self.notice = notice
            publish()
        }
    }

    // Partners are only listed when they are reasonably close to where the user is looking
    private func partners(near center: CLLocation?) -> [Laundromat] {
        PartnerLaundromats.all.compactMap { partner in
            var laundromat = partner
            guard let center else {
                laundromat.distanceMeters = nil
                return laundromat
            }
            let distance = CLLocation(latitude: laundromat.latitude, longitude: laundromat.longitude).distance(from: center)
            guard distance <= partnerRadius else { return nil }
            laundromat.distanceMeters = distance
            return laundromat
        }
    }

    private func publish() {
        let withMachines = results.map { laundromat -> Laundromat in
            guard laundromat.isPartner else { return laundromat }
            var copy = laundromat
            copy.machines = bookings.machines(inLaundromat: laundromat.id)
            return copy
        }
        output?.didFetchLaundromats(LaundromatListResult(laundromats: sorted(withMachines, by: criteria),
                                                         selectedId: store.selected.id,
                                                         savedIds: Set(store.saved.map(\.id)),
                                                         notice: notice))
    }

    // MARK: - Sorting
    private func sorted(_ items: [Laundromat], by criteria: SortingCriteria) -> [Laundromat] {
        switch criteria {
        case .name:
            return items.sorted { $0.name < $1.name }
        case .distance:
            // unknown distance goes last
            return items.sorted {
                ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
            }
        case .rating:
            // best first, unrated last
            return items.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .price:
            // cheapest machine per laundromat; no machine data means unknown price, so last
            return items.sorted {
                (lowestPrice(of: $0) ?? .greatestFiniteMagnitude) < (lowestPrice(of: $1) ?? .greatestFiniteMagnitude)
            }
        case .open:
            // open first, then closed, then unknown
            return items.sorted { openRank($0) < openRank($1) }
        }
    }

    private func lowestPrice(of laundromat: Laundromat) -> Decimal? {
        laundromat.machines.map(\.pricePerCycle).min()
    }

    private func openRank(_ laundromat: Laundromat) -> Int {
        switch laundromat.isOpenNow {
        case true: return 0
        case false: return 1
        default: return 2
        }
    }
}
