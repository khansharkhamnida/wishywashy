//
//  PaymentStore.swift
//  wishywashy
//

import Foundation

/// Payments made in the app, kept on the device until there is a server to hold them.
final class PaymentStore {
    static let shared = PaymentStore()

    private let key = "payments"
    private let defaults = UserDefaults.standard

    var payments: [Payment] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Payment].self, from: data)) ?? []
    }

    func save(_ payment: Payment) {
        var current = payments.filter { $0.id != payment.id }
        current.append(payment)
        defaults.set(try? JSONEncoder().encode(current), forKey: key)
    }

    func markRefunded(id: String) {
        var current = payments
        guard let index = current.firstIndex(where: { $0.id == id }) else { return }
        current[index].status = .refunded
        defaults.set(try? JSONEncoder().encode(current), forKey: key)
    }
}
