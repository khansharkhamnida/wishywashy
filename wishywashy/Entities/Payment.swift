//
//  Payment.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation

enum PaymentStatus: String, Codable {
    case pending, succeeded, failed, refunded
}

enum PaymentMethod: String, Codable {
    case card, eWallet, applePay
}

struct Payment: Codable, Identifiable {
    let id: String
    let bookingId: String
    let userId: String
    let amount: Decimal
    let currency: String
    let method: PaymentMethod
    var status: PaymentStatus
    let createdAt: Date
}
