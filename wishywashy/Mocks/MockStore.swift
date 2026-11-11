//
//  MockStore.swift
//  wishywashy
//
//  Keeps the mock bookings and machines on the device so they survive a restart.
//  The keys carry a version: change it if the saved shape changes, and old data is ignored.
//

import Foundation

enum MockStore {
    static let bookingsKey = "mockBookings.v1"
    static let machinesKey = "mockMachines.v1"

    /// Tests point this at a throwaway suite
    static var defaults = UserDefaults.standard

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
