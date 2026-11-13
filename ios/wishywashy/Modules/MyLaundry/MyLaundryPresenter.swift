//
//  MyLaundryPresenter.swift
//  wishywashy
//

import Foundation

final class MyLaundryPresenter: MyLaundryPresenterProtocol, MyLaundryInteractorOutputProtocol {
    weak var view: MyLaundryViewProtocol?
    var interactor: MyLaundryInteractorInputProtocol?
    var router: MyLaundryRouterProtocol?

    // Reservations that are ready for check-in; a later booking can only be cancelled or checked for arrival
    private var heldIds: Set<String> = []

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

    func viewDidLoad() { interactor?.fetchLaundry() }
    func viewWillAppear() { interactor?.fetchLaundry() }
    func didRequestRefresh() { interactor?.fetchLaundry() }
    func didTapGames() { router?.navigateToGames() }
    func didCheckIn(bookingId: String) { interactor?.prepareCheckIn(bookingId: bookingId) }
    func didCancelReservation(bookingId: String) { interactor?.cancelReservation(bookingId: bookingId) }

    func didTapReservation(bookingId: String) {
        let canCheckIn = heldIds.contains(bookingId)
        view?.showReservationOptions(bookingId: bookingId,
                                     title: canCheckIn ? "Your reservation" : "Your booking",
                                     canCheckIn: canCheckIn)
    }

    func didCheckArrival(bookingId: String) {
        router?.navigateToArrivalCheck(bookingId: bookingId)
    }
    func didTapAllBookings() { router?.navigateToBookings() }

    // MyLaundryInteractorOutputProtocol
    func didFailCheckIn(message: String) {
        view?.showMessage(message)
    }

    // Pay first; the cycle only starts once the payment has gone through
    func didPrepareCheckIn(booking: Booking, description: String) {
        let request = PaymentRequest(bookingId: booking.id, amount: booking.totalPrice, currency: "SGD", description: description)
        Task {
            guard let outcome = await router?.collectPayment(request) else { return }
            switch outcome {
            case .paid(let payment): interactor?.completeCheckIn(bookingId: booking.id, payment: payment)
            case .cancelled: break
            case .failed(let message): view?.showMessage(message)
            }
        }
    }

    func didFetchLaundry(reserved: [BookingDetail], running: [BookingDetail], next: BookingDetail?, plans: [String: ArrivalPlan]) {
        heldIds = Set(reserved.map(\.booking.id))
        var sections: [CycleSectionViewModel] = []
        if !reserved.isEmpty {
            sections.append(CycleSectionViewModel(title: "Reserved", cycles: reserved.map(makeReservedViewModel(from:))))
        }
        if !running.isEmpty {
            sections.append(CycleSectionViewModel(title: "Running now", cycles: running.map(makeRunningViewModel(from:))))
        }
        if let next {
            sections.append(CycleSectionViewModel(title: "Up next", cycles: [makeNextViewModel(from: next, plan: plans[next.booking.id])]))
        }

        let summaryTitle: String
        if !running.isEmpty {
            summaryTitle = "\(running.count) cycle\(running.count == 1 ? "" : "s") running"
        } else if !reserved.isEmpty {
            summaryTitle = "\(reserved.count) machine\(reserved.count == 1 ? "" : "s") reserved"
        } else {
            summaryTitle = "No cycles running"
        }

        let summarySubtitle: String
        if !reserved.isEmpty {
            summarySubtitle = "Tap your reservation to check in"
        } else if next != nil {
            summarySubtitle = "1 up next · fresh clothes soon ✨"
        } else {
            summarySubtitle = "Nothing booked next"
        }
        view?.showLaundry(MyLaundryViewModel(summaryTitle: summaryTitle,
                                             summarySubtitle: summarySubtitle,
                                             sections: sections))
    }

    private func makeReservedViewModel(from detail: BookingDetail) -> CycleViewModel {
        let minutesLeft = Int(ceil((detail.booking.holdExpiresAt ?? Date()).timeIntervalSinceNow / 60))
        return CycleViewModel(bookingId: detail.booking.id,
                              isReserved: true,
                              isScheduled: false,
                              icon: detail.machine?.type == .dryer ? "dryer" : "washer",
                              title: title(for: detail),
                              place: detail.laundromat?.name ?? "Unknown laundromat",
                              status: "Reserved",
                              tone: .peach,
                              progress: nil,
                              timeText: minutesLeft <= 1 ? "Held for under 1 min · tap to check in"
                                                          : "Held for \(minutesLeft) min · tap to check in")
    }

    private func makeRunningViewModel(from detail: BookingDetail) -> CycleViewModel {
        let booking = detail.booking
        let isDryer = detail.machine?.type == .dryer
        let total = booking.endTime.timeIntervalSince(booking.startTime)
        let elapsed = Date().timeIntervalSince(booking.startTime)
        let progress = total > 0 ? CGFloat(min(max(elapsed / total, 0), 1)) : 0

        let minutesLeft = Int(ceil(booking.endTime.timeIntervalSinceNow / 60))
        return CycleViewModel(bookingId: booking.id,
                              isReserved: false,
                              isScheduled: false,
                              icon: isDryer ? "dryer" : "washer",
                              title: title(for: detail),
                              place: detail.laundromat?.name ?? "Unknown laundromat",
                              status: isDryer ? "Drying" : "Washing",
                              tone: isDryer ? .blue : .mint,
                              progress: progress,
                              timeText: minutesLeft <= 0 ? "Finishing soon" : "\(minutesLeft) min left")
    }

    private func makeNextViewModel(from detail: BookingDetail, plan: ArrivalPlan?) -> CycleViewModel {
        let start = detail.booking.startTime
        var status = "Booked"
        var tone: Theme.Tone = .lilac
        var timeText = startText(for: start)

        // The in-app reminder: it works even when notifications are off
        if let plan {
            let leaveTime = timeFormatter.string(from: plan.leaveAt)
            if Date() >= plan.leaveAt {
                status = "Time to leave"
                tone = .pink
                timeText = "Leave now to arrive by \(timeFormatter.string(from: start))"
            } else {
                timeText += " · leave by \(leaveTime)"
            }
        }
        return CycleViewModel(bookingId: detail.booking.id,
                              isReserved: false,
                              isScheduled: true,
                              icon: detail.machine?.type == .dryer ? "dryer" : "washer",
                              title: title(for: detail),
                              place: detail.laundromat?.name ?? "Unknown laundromat",
                              status: status,
                              tone: tone,
                              progress: nil,
                              timeText: timeText)
    }

    private func title(for detail: BookingDetail) -> String {
        detail.machine.map { "\($0.type.rawValue.capitalized) \($0.label)" } ?? "Machine"
    }

    private func startText(for start: Date) -> String {
        let minutes = max(Int(ceil(start.timeIntervalSinceNow / 60)), 0)
        if minutes < 60 { return "Starts in \(minutes) min" }
        if minutes < 24 * 60 {
            let (h, m) = (minutes / 60, minutes % 60)
            return m == 0 ? "Starts in \(h) h" : "Starts in \(h) h \(m) min"
        }
        return "Starts \(dayFormatter.string(from: start)) · \(timeFormatter.string(from: start))"
    }
}
