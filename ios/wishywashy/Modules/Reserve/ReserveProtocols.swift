//
//  ReserveProtocols.swift
//  wishywashy
//

import UIKit

enum ReserveMode {
    case now, later
}

struct ReserveData {
    let machine: Machine
    let laundromat: Laundromat?
    let holdMinutes: Int
    /// When the user could start if they reserve now; nil if the machine cannot be reserved now
    let nowStart: Date?
    /// Bookings can be made for today and this many days after
    let daysAhead: Int
}

struct SlotViewModel {
    let title: String
    let isSelected: Bool
}

struct ReserveViewModel {
    let icon: String
    let machineTitle: String
    let machineSubtitle: String
    let priceText: String
    let cycleText: String
    let mode: ReserveMode
    let nowText: String
    let dayTitles: [String]
    let selectedDay: Int
    let slots: [SlotViewModel]
    let slotsEmptyText: String?
    let paymentNote: String
    let errorMessage: String?
    let buttonTitle: String
    let isButtonEnabled: Bool
}

// Presenter -> View
protocol ReserveViewProtocol: AnyObject {
    func render(_ model: ReserveViewModel)
    func showReserving(_ isReserving: Bool)
}

// View -> Presenter
protocol ReservePresenterProtocol: AnyObject {
    func viewDidLoad()
    func didSelectMode(_ mode: ReserveMode)
    func didSelectDay(at index: Int)
    func didSelectSlot(at index: Int)
    func didTapReserve()
    func didTapCancel()
}

// Presenter -> Interactor
protocol ReserveInteractorInputProtocol: AnyObject {
    func loadMachine()
    func loadSlots(dayOffset: Int)
    func reserveNow()
    func book(at start: Date)
}

// Interactor -> Presenter
protocol ReserveInteractorOutputProtocol: AnyObject {
    func didLoadMachine(_ data: ReserveData)
    func didLoadSlots(_ slots: [Date], dayOffset: Int)
    func didReserve()
    func didFail(_ error: ReserveError)
}

// Presenter -> Router
protocol ReserveRouterProtocol: AnyObject {
    func close()
    /// Closes the sheet, then tells whoever opened it that a machine was reserved
    func closeAfterReserving()
}
