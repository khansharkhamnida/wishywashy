//
//  ArrivalCheckProtocols.swift
//  wishywashy
//

import UIKit

struct ArrivalBookingInfo {
    let detail: BookingDetail
    let checkInDeadline: Date
    let plan: ArrivalPlan?
    let notificationPermission: PermissionState
    let remindersAllowed: Bool
}

struct ArrivalUpdate {
    let plan: ArrivalPlan
    let notificationPermission: PermissionState
    let remindersAllowed: Bool
}

struct ReminderViewModel {
    let isOn: Bool
    let isEnabled: Bool
    let statusText: String
    let showsSettingsButton: Bool
}

struct ArrivalResultViewModel {
    let verdictText: String
    let verdictTone: Theme.Tone
    let detailText: String
    let leaveByText: String
    let countdownText: String?
    let estimateNote: String
    let reminder: ReminderViewModel
}

struct ArrivalCheckViewModel {
    let icon: String
    let machineTitle: String
    let placeText: String
    let arriveByText: String
    let privacyNote: String
    let modeTitles: [String]
    let modeIndex: Int
    let isLoading: Bool
    /// Set when we could not use the user's location; shows the manual inputs with this message
    let manualMessage: String?
    let manualMinutes: Int
    let result: ArrivalResultViewModel?
    let errorMessage: String?
    let checkButtonTitle: String
}

// Presenter -> View
protocol ArrivalCheckViewProtocol: AnyObject {
    func render(_ model: ArrivalCheckViewModel)
}

// View -> Presenter
protocol ArrivalCheckPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didSelectMode(at index: Int)
    func didTapCheck()
    func didTapCalculateManually(place: String, minutes: Int)
    func didToggleReminder(_ isOn: Bool)
    func didTapOpenSettings()
    func didRequestRefresh()
    func didTapClose()
}

// Presenter -> Interactor
protocol ArrivalCheckInteractorInputProtocol: AnyObject {
    func loadBooking()
    func checkWithCurrentLocation(mode: TravelMode)
    func checkManually(place: String, minutes: Int, mode: TravelMode)
    func setReminder(enabled: Bool)
}

// Interactor -> Presenter
protocol ArrivalCheckInteractorOutputProtocol: AnyObject {
    func didLoadBooking(_ info: ArrivalBookingInfo)
    func didNeedManualInput(message: String)
    func didUpdate(_ update: ArrivalUpdate)
    func didFail(message: String)
}

// Presenter -> Router
protocol ArrivalCheckRouterProtocol: AnyObject {
    func close()
    func openSettings()
}
