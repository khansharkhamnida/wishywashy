//
//  LaundromatStore.swift
//  wishywashy
//

import Foundation

/// The laundromat the user picked and the ones they saved, kept on the device.
/// Whole laundromats are stored because search results are not in any fixed list.
final class LaundromatStore {
    static let shared = LaundromatStore()

    private let defaults = UserDefaults.standard
    private let selectedKey = "selectedLaundromat"
    private let savedKey = "savedLaundromats"

    var selected: Laundromat {
        load(Laundromat.self, key: selectedKey) ?? MockLaundromat.all[0]
    }

    func select(_ laundromat: Laundromat) {
        save(laundromat, key: selectedKey)
    }

    var saved: [Laundromat] {
        load([Laundromat].self, key: savedKey) ?? Array(MockLaundromat.all.prefix(2))
    }

    func isSaved(id: String) -> Bool {
        saved.contains { $0.id == id }
    }

    func toggleSaved(_ laundromat: Laundromat) {
        var current = saved
        if let index = current.firstIndex(where: { $0.id == laundromat.id }) {
            current.remove(at: index)
        } else {
            current.append(laundromat)
        }
        save(current, key: savedKey)
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
