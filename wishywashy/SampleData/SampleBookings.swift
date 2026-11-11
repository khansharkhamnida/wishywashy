//
//  SampleBookings.swift
//  wishywashy
//
//  Seed data for the bookings, until they come from a server.
//

import Foundation

enum SampleBookings {
    /// The bookings at first launch. Price, laundromat and cycle length come from the machine,
    /// so they always match. Times are relative to `now`.
    static func make(machines: [Machine], user: User = Session.user, now: Date = Date()) -> [Booking] {
        let calendar = Calendar.current

        func minutes(_ offset: Int) -> Date {
            now.addingTimeInterval(TimeInterval(offset * 60))
        }

        func day(_ offset: Int, hour: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        }

        func booking(_ id: String, machine machineId: String, start: Date, status: BookingStatus) -> Booking {
            guard let machine = machines.first(where: { $0.id == machineId }) else {
                preconditionFailure("SampleBookings refers to unknown machine \(machineId)")
            }
            return Booking(id: id,
                           userId: user.id,
                           laundromatId: machine.laundromatId,
                           machineId: machine.id,
                           startTime: start,
                           endTime: start.addingTimeInterval(TimeInterval(machine.cycleMinutes * 60)),
                           status: status,
                           totalPrice: machine.pricePerCycle,
                           paymentId: status == .pending || status == .cancelled ? nil : "pay-\(id)",
                           createdAt: start.addingTimeInterval(-24 * 3600),
                           holdExpiresAt: status == .confirmed
                               ? start.addingTimeInterval(TimeInterval(BookingRules.holdMinutes * 60)) : nil)
        }

        return [
            // Running now: W02 has 18 min left of 36, D03 has 8 min left of 40
            booking("b1", machine: "w02", start: minutes(-18), status: .inProgress),
            booking("b2", machine: "d03", start: minutes(-32), status: .inProgress),
            // Upcoming
            booking("b3", machine: "d01", start: minutes(125), status: .confirmed),
            booking("b4", machine: "w03", start: day(1, hour: 10), status: .confirmed),
            booking("b5", machine: "w01-l2", start: day(3, hour: 14), status: .pending),
            // Past
            booking("b6", machine: "w01", start: day(-1, hour: 11), status: .completed),
            booking("b7", machine: "d01", start: day(-8, hour: 15), status: .completed),
            booking("b8", machine: "w04", start: day(-12, hour: 20), status: .cancelled)
        ]
    }
}
