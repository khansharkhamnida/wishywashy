//
//  NotificationPreferences.swift
//  wishywashy
//
//  Which notifications the user wants, switched in Profile > Notifications.
//

import Foundation

enum NotificationPreference: String, CaseIterable {
    case cycleDone = "notifyCycleDone"
    case reminders = "notifyReminders"
    case departureReminders = "notifyDepartureReminders"
    case machineFree = "notifyMachineFree"
    case promotions = "notifyPromotions"

    var defaultValue: Bool { self != .promotions }
}

final class NotificationPreferences {
    static let shared = NotificationPreferences()

    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func isOn(_ preference: NotificationPreference) -> Bool {
        store.bool(forKey: preference.rawValue, default: preference.defaultValue)
    }

    func set(_ preference: NotificationPreference, on: Bool) {
        store.set(on, forKey: preference.rawValue)
    }
}
