//
//  ReserveInteractor.swift
//  wishywashy
//

import Foundation

final class ReserveInteractor: ReserveInteractorInputProtocol {
    weak var output: ReserveInteractorOutputProtocol?

    private let machineId: String
    private let bookings: BookingService

    init(machineId: String, bookings: BookingService = Services.bookings) {
        self.machineId = machineId
        self.bookings = bookings
    }

    func loadMachine() {
        guard let machine = bookings.machine(id: machineId) else {
            output?.didFail(.machineUnavailable)
            return
        }
        output?.didLoadMachine(ReserveData(machine: machine,
                                           laundromat: PartnerLaundromats.all.first { $0.id == machine.laundromatId },
                                           holdMinutes: BookingRules.holdMinutes,
                                           nowStart: bookings.nowStart(for: machineId),
                                           daysAhead: BookingRules.daysAhead))
    }

    func loadSlots(dayOffset: Int) {
        output?.didLoadSlots(bookings.slots(machineId: machineId, dayOffset: dayOffset), dayOffset: dayOffset)
    }

    func reserveNow() {
        handle(bookings.book(machineId: machineId, start: nil))
    }

    func book(at start: Date) {
        handle(bookings.book(machineId: machineId, start: start))
    }

    private func handle(_ result: Result<Booking, ReserveError>) {
        switch result {
        case .success: output?.didReserve()
        case .failure(let error): output?.didFail(error)
        }
    }
}
