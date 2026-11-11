//
//  ArrivalCalculator.swift
//  wishywashy
//

import Foundation

enum ArrivalVerdict {
    /// There is still time to leave at the recommended time
    case comfortable
    /// The recommended time has passed, but leaving now still arrives before the start time
    case tight
    /// Leaving now arrives after the start time but inside the check-in window
    case lateWithinWindow
    /// Leaving now arrives after the check-in window has closed
    case tooLate
}

/// Works out whether the user can make it, and when to leave. Kept free of UI and system services.
enum ArrivalCalculator {
    static let bufferMinutes = 10

    static func verdict(now: Date, arriveBy: Date, checkInDeadline: Date, travelMinutes: Int) -> ArrivalVerdict {
        let travel = TimeInterval(travelMinutes * 60)
        let leaveAt = arriveBy.addingTimeInterval(-(travel + TimeInterval(bufferMinutes * 60)))
        let arrivalIfLeavingNow = now.addingTimeInterval(travel)

        if now <= leaveAt { return .comfortable }
        if arrivalIfLeavingNow <= arriveBy { return .tight }
        if arrivalIfLeavingNow <= checkInDeadline { return .lateWithinWindow }
        return .tooLate
    }
}
