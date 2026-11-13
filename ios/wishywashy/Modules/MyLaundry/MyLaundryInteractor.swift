//
//  MyLaundryInteractor.swift
//  wishywashy
//

import Foundation

final class MyLaundryInteractor: MyLaundryInteractorInputProtocol {
    weak var output: MyLaundryInteractorOutputProtocol?

    private let bookings: BookingService

    init(bookings: BookingService = Services.bookings) {
        self.bookings = bookings
    }

    func fetchLaundry() {
        let all = bookings.details
        let reserved = all
            .filter { $0.booking.isHeld }
            .sorted { ($0.booking.holdExpiresAt ?? .distantFuture) < ($1.booking.holdExpiresAt ?? .distantFuture) }
        let running = all
            .filter { $0.booking.status == .inProgress }
            .sorted { $0.booking.endTime < $1.booking.endTime }
        // Only the single next scheduled booking; the rest live in Bookings
        let next = all
            .filter { $0.booking.isScheduled }
            .min { $0.booking.startTime < $1.booking.startTime }
        output?.didFetchLaundry(reserved: reserved, running: running, next: next, plans: ArrivalPlanStore.shared.plans)
    }

    func prepareCheckIn(bookingId: String) {
        switch bookings.canCheckIn(bookingId: bookingId) {
        case .success(let booking):
            let machine = bookings.machine(id: booking.machineId)
            let name = machine.map { "\($0.type.rawValue.capitalized) \($0.label)" } ?? "your machine"
            output?.didPrepareCheckIn(booking: booking, description: "\(name) cycle")
        case .failure(.machineBusy):
            output?.didFailCheckIn(message: "The previous user is still at this machine. Try again in a moment.")
        case .failure(.notReady):
            output?.didFailCheckIn(message: "This reservation can't be checked in right now.")
        }
        fetchLaundry()
    }

    func completeCheckIn(bookingId: String, payment: Payment) {
        PaymentStore.shared.save(payment)
        switch bookings.checkIn(bookingId: bookingId, paymentId: payment.id) {
        case .success:
            // Already at the machine, so no leave reminder is needed
            ArrivalPlanStore.shared.remove(bookingId: bookingId)
        case .failure:
            // The machine was lost while paying, so the payment is returned
            PaymentStore.shared.markRefunded(id: payment.id)
            output?.didFailCheckIn(message: "The machine became unavailable while you were paying, so your payment was refunded.")
        }
        fetchLaundry()
    }

    func cancelReservation(bookingId: String) {
        bookings.cancelReservation(bookingId: bookingId)
        ArrivalPlanStore.shared.remove(bookingId: bookingId)
        fetchLaundry()
    }
}
