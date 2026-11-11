//
//  ReservePresenter.swift
//  wishywashy
//

import Foundation

final class ReservePresenter: ReservePresenterProtocol, ReserveInteractorOutputProtocol {
    weak var view: ReserveViewProtocol?
    var interactor: ReserveInteractorInputProtocol?
    var router: ReserveRouterProtocol?

    private var data: ReserveData?
    private var mode: ReserveMode = .now
    private var dayOffset = 0
    private var slots: [Date] = []
    private var selectedSlot: Date?
    private var errorMessage: String?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    func viewDidLoad() { interactor?.loadMachine() }

    func didSelectMode(_ mode: ReserveMode) {
        self.mode = mode
        errorMessage = nil
        if mode == .later { interactor?.loadSlots(dayOffset: dayOffset) }
        render()
    }

    func didSelectDay(at index: Int) {
        dayOffset = index
        selectedSlot = nil
        errorMessage = nil
        interactor?.loadSlots(dayOffset: index)
    }

    func didSelectSlot(at index: Int) {
        guard slots.indices.contains(index) else { return }
        selectedSlot = slots[index]
        errorMessage = nil
        render()
    }

    func didTapReserve() {
        errorMessage = nil
        switch mode {
        case .now:
            view?.showReserving(true)
            interactor?.reserveNow()
        case .later:
            guard let selectedSlot else { return }
            view?.showReserving(true)
            interactor?.book(at: selectedSlot)
        }
    }

    func didTapCancel() { router?.close() }

    // ReserveInteractorOutputProtocol
    func didLoadMachine(_ data: ReserveData) {
        self.data = data
        // Start on "Later" when the machine cannot be reserved right now
        if data.nowStart == nil, mode == .now {
            mode = .later
            interactor?.loadSlots(dayOffset: dayOffset)
        }
        render()
    }

    func didLoadSlots(_ slots: [Date], dayOffset: Int) {
        guard dayOffset == self.dayOffset else { return }
        self.slots = slots
        if let selectedSlot, !slots.contains(selectedSlot) { self.selectedSlot = nil }
        render()
    }

    func didReserve() {
        view?.showReserving(false)
        router?.closeAfterReserving()
    }

    func didFail(_ error: ReserveError) {
        view?.showReserving(false)
        switch error {
        case .machineUnavailable: errorMessage = "That machine is no longer available then. Pick another time or machine."
        case .alreadyHolding: errorMessage = "You already have a reserved machine waiting for check-in. Check in or cancel it in My Laundry first."
        case .slotTaken: errorMessage = "Someone just booked that time. Pick another one."
        case .tooManyBookings: errorMessage = "You can have up to \(BookingRules.maxUpcoming) upcoming bookings. Cancel one in Bookings first."
        }
        selectedSlot = nil
        // Refresh what is free, because it has just changed
        interactor?.loadMachine()
        interactor?.loadSlots(dayOffset: dayOffset)
        render()
    }

    // MARK: - View model
    private func render() {
        guard let data else { return }
        let machine = data.machine
        let hold = data.holdMinutes

        let nowText: String
        let nowButtonTitle: String
        let nowEnabled: Bool
        if let start = data.nowStart {
            let wait = Int(ceil(start.timeIntervalSinceNow / 60))
            if wait <= 1 {
                nowText = "Starts now. Check in within \(hold) min."
                nowButtonTitle = "Reserve for \(hold) min"
            } else {
                nowText = "Free at \(timeFormatter.string(from: start)) (in \(wait) min). Check in within \(hold) min of then."
                nowButtonTitle = "Reserve for \(timeFormatter.string(from: start))"
            }
            nowEnabled = true
        } else {
            nowText = "Not available right now. Choose a time under Later."
            nowButtonTitle = "Not available now"
            nowEnabled = false
        }

        let buttonTitle: String
        let enabled: Bool
        switch mode {
        case .now:
            (buttonTitle, enabled) = (nowButtonTitle, nowEnabled)
        case .later:
            if let selectedSlot {
                buttonTitle = "Book for \(dayText(offset: dayOffset)) \(timeFormatter.string(from: selectedSlot))"
                enabled = true
            } else {
                (buttonTitle, enabled) = ("Choose a time", false)
            }
        }

        let payment = "You pay \(Money.string(machine.pricePerCycle)) when you check in, by card, PayNow or Apple Pay."

        view?.render(ReserveViewModel(
            icon: machine.type.rawValue,
            machineTitle: "\(machine.type.rawValue.capitalized) \(machine.label)",
            machineSubtitle: "\(data.laundromat?.name ?? "Laundromat") · \(machine.capacityKg) kg",
            priceText: Money.string(machine.pricePerCycle),
            cycleText: "\(machine.cycleMinutes) min cycle",
            mode: mode,
            nowText: nowText,
            dayTitles: (0...data.daysAhead).map { dayText(offset: $0) },
            selectedDay: dayOffset,
            slots: slots.map { SlotViewModel(title: timeFormatter.string(from: $0), isSelected: $0 == selectedSlot) },
            slotsEmptyText: slots.isEmpty ? "No free times this day. Try another day." : nil,
            paymentNote: payment,
            errorMessage: errorMessage,
            buttonTitle: buttonTitle,
            isButtonEnabled: enabled))
    }

    private func dayText(offset: Int) -> String {
        switch offset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default:
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            return dayFormatter.string(from: date)
        }
    }
}
