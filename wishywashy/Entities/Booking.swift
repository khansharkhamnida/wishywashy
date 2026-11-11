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
    /// Set while a reservation is held; the machine is released if the user has not checked in by then
    var holdExpiresAt: Date?
}

/// A booking together with the machine and laundromat it refers to.
struct BookingDetail {
    let booking: Booking
    let machine: Machine?
    let laundromat: Laundromat?
}
