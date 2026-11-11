//
//  ArrivalCheckPresenter.swift
//  wishywashy
//

import Foundation

final class ArrivalCheckPresenter: ArrivalCheckPresenterProtocol, ArrivalCheckInteractorOutputProtocol {
    weak var view: ArrivalCheckViewProtocol?
    var interactor: ArrivalCheckInteractorInputProtocol?
    var router: ArrivalCheckRouterProtocol?

    private enum LastCheck {
        case location
        case manual(place: String, minutes: Int)
    }

    private var info: ArrivalBookingInfo?
    private var plan: ArrivalPlan?
    private var notificationPermission: PermissionState = .notDetermined
    private var remindersAllowed = true
    private var mode: TravelMode = .driving
    private var lastCheck: LastCheck?
    private var isLoading = false
    private var manualMessage: String?
    private var manualMinutes = 20
    private var errorMessage: String?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    // MARK: - View actions
    func viewDidLoad() {
        interactor?.loadBooking()
    }

    func didSelectMode(at index: Int) {
        guard TravelMode.allCases.indices.contains(index) else { return }
        mode = TravelMode.allCases[index]
        // A different way of travelling means a different time, so work it out again
        guard let lastCheck else { render(); return }
        start(lastCheck)
    }

    func didTapCheck() {
        start(.location)
    }

    func didTapCalculateManually(place: String, minutes: Int) {
        manualMinutes = minutes
        start(.manual(place: place, minutes: minutes))
    }

    func didToggleReminder(_ isOn: Bool) {
        errorMessage = nil
        interactor?.setReminder(enabled: isOn)
    }

    func didTapOpenSettings() { router?.openSettings() }
    func didRequestRefresh() { render() }
    func didTapClose() { router?.close() }

    private func start(_ check: LastCheck) {
        lastCheck = check
        isLoading = true
        errorMessage = nil
        render()
        switch check {
        case .location:
            manualMessage = nil
            interactor?.checkWithCurrentLocation(mode: mode)
        case .manual(let place, let minutes):
            interactor?.checkManually(place: place, minutes: minutes, mode: mode)
        }
    }

    // MARK: - ArrivalCheckInteractorOutputProtocol
    func didLoadBooking(_ info: ArrivalBookingInfo) {
        self.info = info
        plan = info.plan
        notificationPermission = info.notificationPermission
        remindersAllowed = info.remindersAllowed
        if let plan {
            mode = plan.mode
            manualMinutes = plan.travelMinutes
        }
        render()
    }

    func didNeedManualInput(message: String) {
        isLoading = false
        manualMessage = message
        render()
    }

    func didUpdate(_ update: ArrivalUpdate) {
        isLoading = false
        manualMessage = nil
        plan = update.plan
        notificationPermission = update.notificationPermission
        remindersAllowed = update.remindersAllowed
        render()
    }

    func didFail(message: String) {
        isLoading = false
        errorMessage = message
        render()
    }

    // MARK: - View model
    private func render() {
        guard let info else {
            // The booking could not be loaded, so there is nothing to check
            if let errorMessage {
                view?.render(ArrivalCheckViewModel(icon: "washer", machineTitle: "Booking unavailable", placeText: "",
                                                   arriveByText: "", privacyNote: "", modeTitles: [], modeIndex: 0,
                                                   isLoading: false, manualMessage: nil, manualMinutes: manualMinutes,
                                                   result: nil, errorMessage: errorMessage, checkButtonTitle: "Close"))
            }
            return
        }
        let booking = info.detail.booking
        let machine = info.detail.machine
        view?.render(ArrivalCheckViewModel(
            icon: machine?.type.rawValue ?? "washer",
            machineTitle: machine.map { "\($0.type.rawValue.capitalized) \($0.label)" } ?? "Your booking",
            placeText: info.detail.laundromat?.name ?? "Laundromat",
            arriveByText: "Arrive by \(timeFormatter.string(from: booking.startTime))",
            privacyNote: "We use your location once to work out the trip. It isn't saved or tracked.",
            modeTitles: TravelMode.allCases.map(\.title),
            modeIndex: TravelMode.allCases.firstIndex(of: mode) ?? 0,
            isLoading: isLoading,
            manualMessage: manualMessage,
            manualMinutes: manualMinutes,
            result: plan.map { makeResult(from: $0, info: info) },
            errorMessage: errorMessage,
            checkButtonTitle: plan == nil ? "Check if I can arrive on time" : "Recalculate"))
    }

    private func makeResult(from plan: ArrivalPlan, info: ArrivalBookingInfo) -> ArrivalResultViewModel {
        let now = Date()
        let verdict = ArrivalCalculator.verdict(now: now, arriveBy: plan.arriveBy,
                                                checkInDeadline: info.checkInDeadline, travelMinutes: plan.travelMinutes)
        let arrivalNow = now.addingTimeInterval(TimeInterval(plan.travelMinutes * 60))
        let arrivalText = timeFormatter.string(from: arrivalNow)
        let buffer = plan.bufferMinutes

        let verdictText: String
        let tone: Theme.Tone
        var extra: String?
        var leaveBy = "Leave by \(timeFormatter.string(from: plan.leaveAt))"
        var countdown: String?

        switch verdict {
        case .comfortable:
            verdictText = "You can get there on time"
            tone = .mint
            let minutesLeft = Int(ceil(plan.leaveAt.timeIntervalSince(now) / 60))
            countdown = minutesLeft <= 1 ? "Leave in about a minute" : "Leave in \(minutesLeft) min"
        case .tight:
            verdictText = "Leave now to arrive on time"
            tone = .peach
            leaveBy = "Leave now"
            extra = "You'd arrive around \(arrivalText), with less than your \(buffer) min buffer."
        case .lateWithinWindow:
            let late = Int(ceil(arrivalNow.timeIntervalSince(plan.arriveBy) / 60))
            verdictText = "You'd be about \(late) min late"
            tone = .peach
            leaveBy = "Leave now"
            extra = "You'd still arrive inside the \(BookingRules.holdMinutes) min check-in window, around \(arrivalText)."
        case .tooLate:
            verdictText = "You may miss this booking"
            tone = .pink
            leaveBy = "Leave now"
            extra = "You'd arrive around \(arrivalText), after check-in closes at \(timeFormatter.string(from: info.checkInDeadline)). Consider cancelling or booking a later time."
        }

        let travel = plan.isManualEstimate
            ? "\(plan.travelMinutes) min (your estimate)"
            : "About \(plan.travelMinutes) min \(plan.mode.phrase)"
        let detail = ["\(travel) + \(buffer) min buffer", extra].compactMap { $0 }.joined(separator: "\n")

        return ArrivalResultViewModel(
            verdictText: verdictText,
            verdictTone: tone,
            detailText: detail,
            leaveByText: leaveBy,
            countdownText: countdown,
            estimateNote: plan.isManualEstimate
                ? "Based on the time you entered. Recalculate if your plans change."
                : "Travel time is an estimate from Apple Maps and can change with traffic. Recalculate any time.",
            reminder: makeReminder(plan: plan, verdict: verdict))
    }

    private func makeReminder(plan: ArrivalPlan, verdict: ArrivalVerdict) -> ReminderViewModel {
        let time = timeFormatter.string(from: plan.leaveAt)
        if !remindersAllowed {
            return ReminderViewModel(isOn: false, isEnabled: false,
                                     statusText: "Departure reminders are off in Profile > Notifications. You'll see a countdown here and on My Laundry instead.",
                                     showsSettingsButton: false)
        }
        if notificationPermission == .denied {
            return ReminderViewModel(isOn: false, isEnabled: false,
                                     statusText: "Notifications are off for this app. You'll see a countdown here and on My Laundry instead.",
                                     showsSettingsButton: true)
        }
        if verdict != .comfortable {
            return ReminderViewModel(isOn: false, isEnabled: false,
                                     statusText: "It's already time to leave, so there is no reminder to set.",
                                     showsSettingsButton: false)
        }
        return ReminderViewModel(isOn: plan.reminderOn, isEnabled: true,
                                 statusText: plan.reminderOn ? "We'll notify you at \(time)." : "Get a notification at \(time).",
                                 showsSettingsButton: false)
    }
}
