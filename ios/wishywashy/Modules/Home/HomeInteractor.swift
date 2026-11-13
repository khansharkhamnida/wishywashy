//
//  HomeInteractor.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//
import Foundation

class HomeInteractor: HomeInteractorInputProtocol {
    weak var output: HomeInteractorOutputProtocol?   // weak = avoids a retain cycle

    private let bookings: BookingService

    init(bookings: BookingService = Services.bookings) {
        self.bookings = bookings
    }

    func fetchHomeData() {
        publish(machineType: nil)
    }

    /// Simulates a network reload; the short delay lets the refresh spinner show with mock data
    func refreshHomeData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.publish(machineType: nil)
        }
    }

    /// Shows machines of the given type first, then the rest. Each group is sorted available first.
    func sortMachines(by type: MachineType) {
        publish(machineType: type)
    }

    // TODO: handle failure

    private func publish(machineType: MachineType?) {
        let laundromat = LaundromatStore.shared.selected
        let machines = bookings.machines(inLaundromat: laundromat.id)
        let data = HomeData(user: Session.user,
                            laundromat: laundromat,
                            machines: Self.sorted(machines, preferring: machineType))
        output?.didFetchHomeData(data)
    }

    private static func sorted(_ machines: [Machine], preferring type: MachineType?) -> [Machine] {
        machines.sorted { lhs, rhs in
            if let type, (lhs.type == type) != (rhs.type == type) { return lhs.type == type }
            if rank(lhs.status) != rank(rhs.status) { return rank(lhs.status) < rank(rhs.status) }
            // Busy machines that free up soonest come first, unknown finish times last
            if lhs.status == .inUse, lhs.availableAt != rhs.availableAt {
                return (lhs.availableAt ?? .distantFuture) < (rhs.availableAt ?? .distantFuture)
            }
            return lhs.label < rhs.label
        }
    }

    private static func rank(_ status: MachineStatus) -> Int {
        switch status {
        case .available: 0
        case .inUse: 1
        case .reserved: 2
        case .outOfOrder: 3
        }
    }
}
