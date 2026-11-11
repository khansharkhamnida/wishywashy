//
//  MyLaundryProtocols.swift
//  wishywashy
//

import UIKit

struct CycleViewModel {
    let bookingId: String
    /// True for a held reservation the user can check in to or cancel
    let isReserved: Bool
    /// True for the next booking, which can be cancelled or checked for arrival time
    let isScheduled: Bool
    let icon: String
    let title: String
    let place: String
    let status: String
    let tone: Theme.Tone
    let progress: CGFloat?
    let timeText: String
}

struct CycleSectionViewModel {
    let title: String
    let cycles: [CycleViewModel]
}

struct MyLaundryViewModel {
    let summaryTitle: String
    let summarySubtitle: String
    let sections: [CycleSectionViewModel]
}

// Presenter -> View
protocol MyLaundryViewProtocol: AnyObject {
    func showLaundry(_ model: MyLaundryViewModel)
    func showReservationOptions(bookingId: String, title: String, canCheckIn: Bool)
    func showMessage(_ text: String)
}

// View -> Presenter
protocol MyLaundryPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func didRequestRefresh()
    func didTapReservation(bookingId: String)
    func didCheckIn(bookingId: String)
    func didCancelReservation(bookingId: String)
    func didCheckArrival(bookingId: String)
    func didTapGames()
    func didTapAllBookings()
}

// Presenter -> Interactor
protocol MyLaundryInteractorInputProtocol: AnyObject {
    func fetchLaundry()
    func prepareCheckIn(bookingId: String)
    func completeCheckIn(bookingId: String, payment: Payment)
    func cancelReservation(bookingId: String)
}

// Interactor -> Presenter
protocol MyLaundryInteractorOutputProtocol: AnyObject {
    func didFailCheckIn(message: String)
    /// The booking can be checked in, so the user can now be asked to pay
    func didPrepareCheckIn(booking: Booking, description: String)
    func didFetchLaundry(reserved: [BookingDetail], running: [BookingDetail], next: BookingDetail?, plans: [String: ArrivalPlan])
}

// Presenter -> Router
protocol MyLaundryRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToGames()
    func navigateToBookings()
    func navigateToArrivalCheck(bookingId: String)
    func collectPayment(_ request: PaymentRequest) async -> PaymentOutcome
}
