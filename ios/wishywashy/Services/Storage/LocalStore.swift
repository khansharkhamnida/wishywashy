//
//  LocalStore.swift
//  wishywashy
//
//  The one place that reads and writes saved data on the device.
//  Tests give it their own UserDefaults suite so they never touch real data.
//

import Foundation

enum StoreKey {
    // The version in a key changes when the saved shape changes, and old data is then ignored
    static let bookings = "mockBookings.v1"
    static let machines = "mockMachines.v1"
    static let payments = "payments"
    static let arrivalPlans = "arrivalPlans"
    static let selectedLaundromat = "selectedLaundromat"
    static let savedLaundromats = "savedLaundromats"
}

final class LocalStore {
    static let shared = LocalStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    func bool(forKey key: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func int(forKey key: String) -> Int {
        defaults.integer(forKey: key)
    }

    func set(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
