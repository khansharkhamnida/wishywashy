//
//  MyLaundryInteractor.swift
//  wishywashy
//

import Foundation

final class MyLaundryInteractor: MyLaundryInteractorInputProtocol {
    weak var output: MyLaundryInteractorOutputProtocol?

    func fetchLaundry() {
        let all = MockBooking.details
        let reserved = all
            .filter { MockBooking.isHeld($0.booking) }
            .sorted { ($0.booking.holdExpiresAt ?? .distantFuture) < ($1.booking.holdExpiresAt ?? .distantFuture) }
        let running = all
            .filter { $0.booking.status == .inProgress }
            .sorted { $0.booking.endTime < $1.booking.endTime }
        // Only the single next scheduled booking; the rest live in Bookings
        let next = all
            .filter { MockBooking.isScheduled($0.booking) }
            .min { $0.booking.startTime < $1.booking.startTime }
        output?.didFetchLaundry(reserved: reserved, running: running, next: next, plans: ArrivalPlanStore.shared.plans)
    }

    func prepareCheckIn(bookingId: String) {
        switch MockBooking.canCheckIn(bookingId: bookingId) {
        case .success(let booking):
            let machine = MockMachines.all.first { $0.id == booking.machineId }
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
        switch MockBooking.checkIn(bookingId: bookingId, paymentId: payment.id) {
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
        MockBooking.cancelReservation(bookingId: bookingId)
        ArrivalPlanStore.shared.remove(bookingId: bookingId)
        fetchLaundry()
    }
}
