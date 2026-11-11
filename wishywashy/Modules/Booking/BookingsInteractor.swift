//
//  BookingsInteractor.swift
//  wishywashy
//

import Foundation

final class BookingsInteractor: BookingsInteractorInputProtocol {
    weak var output: BookingsInteractorOutputProtocol?

    private let bookings: BookingService

    init(bookings: BookingService = Services.bookings) {
        self.bookings = bookings
    }

    func cancelBooking(id: String) {
        bookings.cancelReservation(bookingId: id)
        // No leave reminder for a booking that no longer exists
        ArrivalPlanStore.shared.remove(bookingId: id)
    }

    func fetchBookings(filter: BookingFilter) {
        let all = bookings.details
        switch filter {
        case .upcoming:
            // Running cycles first, then the soonest booking
            let items = all
                .filter { [.inProgress, .confirmed, .pending].contains($0.booking.status) }
                .sorted {
                    let (a, b) = ($0.booking, $1.booking)
                    if (a.status == .inProgress) != (b.status == .inProgress) { return a.status == .inProgress }
                    return a.startTime < b.startTime
                }
            output?.didFetchBookings(items)
        case .past:
            // Most recent first
            let items = all
                .filter { [.completed, .cancelled, .expired].contains($0.booking.status) }
                .sorted { $0.booking.startTime > $1.booking.startTime }
            output?.didFetchBookings(items)
        }
    }
}
