//
//  LaundromatStore.swift
//  wishywashy
//

import Foundation

/// The laundromat the user picked and the ones they saved, kept on the device.
/// Whole laundromats are stored because search results are not in any fixed list.
final class LaundromatStore {
    static let shared = LaundromatStore()

    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    var selected: Laundromat {
        store.load(Laundromat.self, key: StoreKey.selectedLaundromat) ?? PartnerLaundromats.all[0]
    }

    func select(_ laundromat: Laundromat) {
        store.save(laundromat, key: StoreKey.selectedLaundromat)
    }

    var saved: [Laundromat] {
        store.load([Laundromat].self, key: StoreKey.savedLaundromats) ?? Array(PartnerLaundromats.all.prefix(2))
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
        store.save(current, key: StoreKey.savedLaundromats)
    }
}
