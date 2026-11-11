//
//  LaundromatListPresenter.swift
//  wishywashy
//

import Foundation

final class LaundromatListPresenter: LaundromatListPresenterProtocol, LaundromatListInteractorOutputProtocol {

    weak var view: LaundromatListViewProtocol?
    var interactor: LaundromatListInteractorInputProtocol?
    var router: LaundromatListRouterProtocol?

    // Same order as what the view shows, so an index maps to the right entity
    private var laundromats: [Laundromat] = []

    func viewDidLoad() {
        interactor?.fetchLaundromats()
    }

    func didSelectSort(_ criteria: SortingCriteria) {
        interactor?.sortLaundromats(by: criteria)
    }

    func didSearchLocation(_ query: String) {
        interactor?.searchLocation(query)
    }

    func didToggleSaved(at index: Int) {
        guard laundromats.indices.contains(index) else { return }
        interactor?.toggleSaved(id: laundromats[index].id)
    }

    func didSelectLaundromat(at index: Int) {
        guard laundromats.indices.contains(index) else { return }
        interactor?.selectLaundromat(id: laundromats[index].id)
        router?.close()
    }

    // LaundromatListInteractorOutputProtocol
    func didStartLoading() {
        view?.showLoading(true)
    }

    func didFetchLaundromats(_ result: LaundromatListResult) {
        laundromats = result.laundromats
        view?.showLoading(false)
        view?.showLaundromats(result.laundromats.map { makeViewModel(from: $0, result: result) }, notice: result.notice)
    }

    func didFail(message: String) {
        laundromats = []
        view?.showLoading(false)
        view?.showError(message)
    }

    private func makeViewModel(from laundromat: Laundromat, result: LaundromatListResult) -> LaundromatListViewModel {
        let (status, tone) = statusText(for: laundromat.isOpenNow)
        return LaundromatListViewModel(
            name: laundromat.name,
            address: laundromat.address,
            distance: distanceText(laundromat.distanceMeters),
            rating: laundromat.rating.map { "★ \(String(format: "%.1f", $0))" } ?? (laundromat.isPartner ? "New" : ""),
            status: status,
            tone: tone,
            isSelected: laundromat.id == result.selectedId,
            isSaved: result.savedIds.contains(laundromat.id),
            showsMachines: laundromat.isPartner,
            washersFree: freeCount(of: .washer, in: laundromat),
            dryersFree: freeCount(of: .dryer, in: laundromat)
        )
    }

    private func statusText(for isOpen: Bool?) -> (String, Theme.Tone) {
        switch isOpen {
        case true: return ("Open", .mint)
        case false: return ("Closed", .pink)
        default: return ("Hours unknown", .lilac)
        }
    }

    private func distanceText(_ meters: Double?) -> String {
        guard let meters else { return "Distance unknown" }
        return meters < 1000 ? "\(Int(meters)) m" : String(format: "%.1f km", meters / 1000)
    }

    private func freeCount(of type: MachineType, in laundromat: Laundromat) -> Int {
        laundromat.machines.filter { $0.type == type && $0.status == .available }.count
    }
}
