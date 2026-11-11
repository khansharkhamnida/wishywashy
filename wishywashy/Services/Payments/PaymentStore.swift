//
//  PaymentStore.swift
//  wishywashy
//

import Foundation

/// Payments made in the app, kept on the device until there is a server to hold them.
final class PaymentStore {
    static let shared = PaymentStore()

    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    var payments: [Payment] {
        store.load([Payment].self, key: StoreKey.payments) ?? []
    }

    func save(_ payment: Payment) {
        var current = payments.filter { $0.id != payment.id }
        current.append(payment)
        store.save(current, key: StoreKey.payments)
    }

    func markRefunded(id: String) {
        var current = payments
        guard let index = current.firstIndex(where: { $0.id == id }) else { return }
        current[index].status = .refunded
        store.save(current, key: StoreKey.payments)
    }
}
