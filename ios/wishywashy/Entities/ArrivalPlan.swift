//
//  ArrivalPlan.swift
//  wishywashy
//

import Foundation

enum TravelMode: String, Codable, CaseIterable {
    case driving, walking, transit

    var title: String {
        switch self {
        case .driving: return "Drive"
        case .walking: return "Walk"
        case .transit: return "Transit"
        }
    }

    /// Used in sentences such as "about 25 min by car"
    var phrase: String {
        switch self {
        case .driving: return "by car"
        case .walking: return "on foot"
        case .transit: return "by public transport"
        }
    }
}

/// When the user should leave to reach the laundromat for a booking
struct ArrivalPlan: Codable {
    let bookingId: String
    let arriveBy: Date
    let travelMinutes: Int
    let bufferMinutes: Int
    let mode: TravelMode
    /// True when the user typed the travel time instead of it coming from Apple Maps
    let isManualEstimate: Bool
    var reminderOn: Bool

    var leaveAt: Date {
        arriveBy.addingTimeInterval(-TimeInterval((travelMinutes + bufferMinutes) * 60))
    }
}
