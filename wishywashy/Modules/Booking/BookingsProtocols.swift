//
//  BookingsProtocols.swift
//  wishywashy
//

import UIKit

enum BookingFilter {
    case upcoming, past
}

struct BookingCardViewModel {
    let bookingId: String
    /// True while the booking is a reservation that has not been checked in
    let canCancel: Bool
    let icon: String
    let title: String
    let place: String
    let date: String
    let price: String
    let status: String
    let tone: Theme.Tone
}

// Presenter -> View
protocol BookingsViewProtocol: AnyObject {
    func showBookings(_ items: [BookingCardViewModel], emptyMessage: String)
    func showBookingOptions(bookingId: String, title: String)
}

// View -> Presenter
protocol BookingsPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func didSelectFilter(_ filter: BookingFilter)
    func didTapBooking(id: String)
    func didCheckArrival(id: String)
    func didCancelBooking(id: String)
}

// Presenter -> Interactor
protocol BookingsInteractorInputProtocol: AnyObject {
    func fetchBookings(filter: BookingFilter)
    func cancelBooking(id: String)
}

// Interactor -> Presenter
protocol BookingsInteractorOutputProtocol: AnyObject {
    func didFetchBookings(_ items: [BookingDetail])
}

protocol BookingsRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToArrivalCheck(bookingId: String)
}
