//
//  PaymentMethodStore.swift
//  wishywashy
//

import Foundation

struct SavedPaymentMethod: Identifiable {
    let id: String
    let kind: PaymentMethod
    let title: String
    let detail: String
    var isDefault: Bool
}

/// The user's saved payment methods. Kept in memory, with sample ones to start.
final class PaymentMethodStore {
    static let shared = PaymentMethodStore()

    private(set) var all: [SavedPaymentMethod] = [
        SavedPaymentMethod(id: "pm1", kind: .card, title: "Visa •••• 4242", detail: "Expires 08/28", isDefault: true),
        SavedPaymentMethod(id: "pm2", kind: .applePay, title: "Apple Pay", detail: "Shofia's iPhone", isDefault: false),
        SavedPaymentMethod(id: "pm3", kind: .eWallet, title: "GrabPay", detail: "+65 •••• 1234", isDefault: false)
    ]

    func setDefault(id: String) {
        all = all.map { var method = $0; method.isDefault = ($0.id == id); return method }
    }

    func remove(id: String) {
        let wasDefault = all.first { $0.id == id }?.isDefault ?? false
        all.removeAll { $0.id == id }
        if wasDefault, !all.isEmpty { all[0].isDefault = true }
    }

    /// Stands in for a real "add card" flow: adds a sample method of the chosen kind.
    func add(kind: PaymentMethod) {
        let method: SavedPaymentMethod
        switch kind {
        case .card:
            method = SavedPaymentMethod(id: UUID().uuidString, kind: .card, title: "Mastercard •••• 5521",
                                        detail: "Expires 03/29", isDefault: all.isEmpty)
        case .eWallet:
            method = SavedPaymentMethod(id: UUID().uuidString, kind: .eWallet, title: "GrabPay",
                                        detail: "+65 •••• 8890", isDefault: all.isEmpty)
        case .payNow:
            method = SavedPaymentMethod(id: UUID().uuidString, kind: .payNow, title: "PayNow",
                                        detail: "+65 •••• 8890", isDefault: all.isEmpty)
        case .applePay:
            method = SavedPaymentMethod(id: UUID().uuidString, kind: .applePay, title: "Apple Pay",
                                        detail: "Shofia's iPhone", isDefault: all.isEmpty)
        }
        all.append(method)
    }
}
