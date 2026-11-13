//
//  BookingsPresenter.swift
//  wishywashy
//

import Foundation

final class BookingsPresenter: BookingsPresenterProtocol, BookingsInteractorOutputProtocol {
    weak var view: BookingsViewProtocol?
    var interactor: BookingsInteractorInputProtocol?
    var router: BookingsRouterProtocol?

    private var filter: BookingFilter = .upcoming

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    func viewDidLoad() {
        interactor?.fetchBookings(filter: filter)
    }

    func viewWillAppear() {
        interactor?.fetchBookings(filter: filter)
    }

    func didSelectFilter(_ filter: BookingFilter) {
        self.filter = filter
        interactor?.fetchBookings(filter: filter)
    }

    func didTapBooking(id: String) {
        view?.showBookingOptions(bookingId: id, title: "Your booking")
    }

    func didCheckArrival(id: String) {
        router?.navigateToArrivalCheck(bookingId: id)
    }

    func didCancelBooking(id: String) {
        interactor?.cancelBooking(id: id)
        interactor?.fetchBookings(filter: filter)
    }

    // BookingsInteractorOutputProtocol
    func didFetchBookings(_ items: [BookingDetail]) {
        let message = filter == .upcoming ? "No upcoming bookings" : "No past bookings"
        view?.showBookings(items.map(makeViewModel(from:)), emptyMessage: message)
    }

    private func makeViewModel(from detail: BookingDetail) -> BookingCardViewModel {
        let booking = detail.booking
        let type = detail.machine?.type ?? .washer
        let machineName = detail.machine.map { "\($0.type.rawValue.capitalized) \($0.label)" } ?? "Machine"
        let (status, tone) = booking.isHeld ? ("Reserved", Theme.Tone.peach) : statusText(for: booking.status)
        return BookingCardViewModel(
            bookingId: booking.id,
            canCancel: booking.isActiveReservation,
            icon: type.rawValue,
            title: machineName,
            place: detail.laundromat?.name ?? "Unknown laundromat",
            date: dateText(for: booking),
            price: Money.string(booking.totalPrice),
            status: status,
            tone: tone
        )
    }

    private func dateText(for booking: Booking) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(booking.startTime) {
            day = "Today"
        } else if calendar.isDateInTomorrow(booking.startTime) {
            day = "Tomorrow"
        } else if calendar.isDateInYesterday(booking.startTime) {
            day = "Yesterday"
        } else {
            day = dayFormatter.string(from: booking.startTime)
        }
        return "\(day) · \(timeFormatter.string(from: booking.startTime)) – \(timeFormatter.string(from: booking.endTime))"
    }

    private func statusText(for status: BookingStatus) -> (String, Theme.Tone) {
        switch status {
        case .inProgress: return ("In progress", .mint)
        case .confirmed: return ("Confirmed", .blue)
        case .pending: return ("Pending", .peach)
        case .completed: return ("Completed", .lilac)
        case .cancelled: return ("Cancelled", .pink)
        case .expired: return ("Expired", .pink)
        }
    }
}
