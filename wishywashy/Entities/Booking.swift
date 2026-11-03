//
//  Booking.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation

enum BookingStatus: String, Codable {
    case pending, confirmed, inProgress, completed, cancelled, expired
}

struct Booking: Codable, Identifiable {
    let id: String
    let userId: String
    let laundromatId: String
    let machineId: String
    var startTime: Date
    var endTime: Date
    var status: BookingStatus
    var totalPrice: Decimal
    var paymentId: String?
    let createdAt: Date
}
