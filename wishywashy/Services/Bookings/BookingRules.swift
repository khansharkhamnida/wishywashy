//
//  BookingRules.swift
//  wishywashy
//
//  The booking limits, in one place. A server would enforce the same numbers.
//

import Foundation

enum BookingRules {
    /// How long after the start time the user can still check in
    static let holdMinutes = 10
    /// If the previous cycle on a machine runs over, a booking waits at most this long past its start time
    static let maxWaitMinutes = 30
    /// A busy machine can be reserved for "now" if it frees up within this many minutes
    static let finishingSoonMinutes = 15
    static let slotStepMinutes = 30
    /// Bookings can be made for today and this many days after
    static let daysAhead = 2
    static let maxUpcoming = 5
    /// Every laundromat opens and closes at these hours
    static let openingHour = 7
    static let closingHour = 23
}

extension Booking {
    /// Reserved or booked, and not yet checked in
    var isActiveReservation: Bool {
        status == .confirmed && holdExpiresAt != nil
    }

    /// The start time has come and the user can check in now
    var isHeld: Bool {
        isActiveReservation && startTime <= Date()
    }

    /// Confirmed for a later start time
    var isScheduled: Bool {
        isActiveReservation && startTime > Date()
    }
}
