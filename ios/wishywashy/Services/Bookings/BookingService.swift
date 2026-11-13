//
//  BookingService.swift
//  wishywashy
//

import Foundation

enum ReserveError: Error {
    case machineUnavailable
    case alreadyHolding
    case slotTaken
    case tooManyBookings
}

enum CheckInError: Error {
    case notReady
    case machineBusy
}

/// Everything the screens need to know about machines and bookings, and every change they can make.
/// Today `LocalBookingService` answers on the device. A server would answer the same questions.
protocol BookingService: AnyObject {
    // MARK: Reading
    var bookings: [Booking] { get }
    var details: [BookingDetail] { get }
    func machines(inLaundromat laundromatId: String) -> [Machine]
    func machine(id: String) -> Machine?

    // MARK: Availability
    /// When the user could start if they reserve "now", or nil if the machine cannot be reserved now
    func nowStart(for machineId: String) -> Date?
    /// Free start times on one day, `dayOffset` days from today
    func slots(machineId: String, dayOffset: Int) -> [Date]

    // MARK: Changes
    /// Books a machine. `start` nil means "now" (see `nowStart`). Nothing is charged until check-in.
    func book(machineId: String, start: Date?) -> Result<Booking, ReserveError>
    /// Whether the user can check in right now, without changing anything. Used before taking payment.
    func canCheckIn(bookingId: String) -> Result<Booking, CheckInError>
    /// Starts the cycle once it has been paid for
    func checkIn(bookingId: String, paymentId: String) -> Result<Void, CheckInError>
    /// Cancels a reservation or a later booking that has not been checked in. It is free.
    func cancelReservation(bookingId: String)
}
