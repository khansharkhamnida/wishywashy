//
//  ReserveInteractor.swift
//  wishywashy
//

import Foundation

final class ReserveInteractor: ReserveInteractorInputProtocol {
    weak var output: ReserveInteractorOutputProtocol?

    private let machineId: String

    init(machineId: String) {
        self.machineId = machineId
    }

    func loadMachine() {
        guard let machine = MockMachines.all.first(where: { $0.id == machineId }) else {
            output?.didFail(.machineUnavailable)
            return
        }
        output?.didLoadMachine(ReserveData(machine: machine,
                                           laundromat: MockLaundromat.all.first { $0.id == machine.laundromatId },
                                           holdMinutes: MockBooking.holdMinutes,
                                           nowStart: MockBooking.nowStart(for: machineId),
                                           daysAhead: MockBooking.daysAhead))
    }

    func loadSlots(dayOffset: Int) {
        output?.didLoadSlots(MockBooking.slots(machineId: machineId, dayOffset: dayOffset), dayOffset: dayOffset)
    }

    func reserveNow() {
        handle(MockBooking.book(machineId: machineId, start: nil))
    }

    func book(at start: Date) {
        handle(MockBooking.book(machineId: machineId, start: start))
    }

    private func handle(_ result: Result<Booking, ReserveError>) {
        switch result {
        case .success: output?.didReserve()
        case .failure(let error): output?.didFail(error)
        }
    }
}
