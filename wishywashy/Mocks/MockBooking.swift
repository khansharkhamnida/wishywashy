//
//  MockBooking.swift
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

/// One shared list of bookings, so Bookings, My Laundry, Profile and Home always agree.
/// It also plays the part of the server: it applies the booking rules, and it is saved on the device.
///
/// A booking is `confirmed` with a `holdExpiresAt`. From its start time the user has `holdMinutes`
/// to check in. If they do not, it expires and the machine is released.
enum MockBooking {
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
    /// Every mock laundromat opens and closes at these hours
    static let openingHour = 7
    static let closingHour = 23

    // Used only to build the sample bookings the first time the app runs
    private static let launch = Date()
    private static let calendar = Calendar.current

    private static var storage: [Booking] = MockStore.load([Booking].self, key: MockStore.bookingsKey) ?? samples

    private static let samples: [Booking] = [
        // Running now: W02 has 18 min left of 36, D03 has 8 min left of 40
        make("b1", machine: "w02", start: minutes(-18), status: .inProgress),
        make("b2", machine: "d03", start: minutes(-32), status: .inProgress),
        // Upcoming
        make("b3", machine: "d01", start: minutes(125), status: .confirmed),
        make("b4", machine: "w03", start: day(1, hour: 10), status: .confirmed),
        make("b5", machine: "w01-l2", start: day(3, hour: 14), status: .pending),
        // Past
        make("b6", machine: "w01", start: day(-1, hour: 11), status: .completed),
        make("b7", machine: "d01", start: day(-8, hour: 15), status: .completed),
        make("b8", machine: "w04", start: day(-12, hour: 20), status: .cancelled)
    ]

    static var all: [Booking] {
        advance()
        return storage
    }

    static var details: [BookingDetail] {
        all.map { booking in
            BookingDetail(booking: booking,
                          machine: MockMachines.stored.first { $0.id == booking.machineId },
                          laundromat: MockLaundromat.all.first { $0.id == booking.laundromatId })
        }
    }

    // MARK: - Booking states
    /// The start time has come and the user can check in now
    static func isHeld(_ booking: Booking) -> Bool {
        booking.status == .confirmed && booking.holdExpiresAt != nil && booking.startTime <= Date()
    }

    /// Confirmed for a later start time
    static func isScheduled(_ booking: Booking) -> Bool {
        booking.status == .confirmed && booking.holdExpiresAt != nil && booking.startTime > Date()
    }

    // MARK: - Availability
    /// When the user could start if they reserve "now": straight away for a free machine,
    /// or when a busy one frees up, if that is soon. Nil if it cannot be reserved now.
    static func nowStart(for machineId: String) -> Date? {
        advance()
        guard let machine = MockMachines.stored.first(where: { $0.id == machineId }) else { return nil }
        let now = Date()
        let candidate: Date
        switch machine.status {
        case .available:
            candidate = now
        case .inUse:
            guard let free = machine.availableAt,
                  free.timeIntervalSince(now) <= TimeInterval(finishingSoonMinutes * 60) else { return nil }
            candidate = max(free, now)
        case .reserved, .outOfOrder:
            return nil
        }
        return canBook(machine, start: candidate) ? candidate : nil
    }

    /// Free start times on one day, `dayOffset` days from today
    static func slots(machineId: String, dayOffset: Int) -> [Date] {
        advance()
        guard let machine = MockMachines.stored.first(where: { $0.id == machineId }),
              let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) else { return [] }
        let (open, close) = hours(on: day)
        var result: [Date] = []
        var time = open
        while time < close {
            if time > Date(), canBook(machine, start: time) { result.append(time) }
            time = time.addingTimeInterval(TimeInterval(slotStepMinutes * 60))
        }
        return result
    }

    // MARK: - Rules
    /// Books a machine. `start` nil means "now" (see `nowStart`). Nothing is charged until check-in.
    static func book(machineId: String, start: Date?) -> Result<Booking, ReserveError> {
        advance()
        guard let machine = MockMachines.stored.first(where: { $0.id == machineId }) else {
            return .failure(.machineUnavailable)
        }
        let begin: Date
        if let start {
            begin = start
        } else {
            // One reservation at a time can be waiting for check-in, so nobody blocks several machines
            if storage.contains(where: { isHeld($0) }) { return .failure(.alreadyHolding) }
            guard let soonest = nowStart(for: machineId) else { return .failure(.machineUnavailable) }
            begin = soonest
        }
        let upcoming = storage.filter { $0.status == .confirmed && $0.holdExpiresAt != nil }.count
        if upcoming >= maxUpcoming { return .failure(.tooManyBookings) }
        guard canBook(machine, start: begin) else {
            return .failure(start == nil ? .machineUnavailable : .slotTaken)
        }

        let booking = Booking(id: "b\(UUID().uuidString.prefix(8))",
                              userId: MockUser.current.id,
                              laundromatId: machine.laundromatId,
                              machineId: machine.id,
                              startTime: begin,
                              endTime: begin.addingTimeInterval(TimeInterval(machine.cycleMinutes * 60)),
                              status: .confirmed,
                              totalPrice: machine.pricePerCycle,
                              paymentId: nil,
                              createdAt: Date(),
                              holdExpiresAt: begin.addingTimeInterval(TimeInterval(holdMinutes * 60)))
        storage.append(booking)
        advance()
        commit()
        return .success(booking)
    }

    /// Whether the user can check in right now, without changing anything. Used before taking payment.
    static func canCheckIn(bookingId: String) -> Result<Booking, CheckInError> {
        advance()
        guard let booking = storage.first(where: { $0.id == bookingId }), isHeld(booking),
              let machine = MockMachines.stored.first(where: { $0.id == booking.machineId }) else {
            return .failure(.notReady)
        }
        // The machine only turns "reserved" once the previous user has left
        guard machine.status == .reserved else { return .failure(.machineBusy) }
        return .success(booking)
    }

    /// Starts the cycle once it has been paid for. Stands in for scanning the QR code on the machine.
    static func checkIn(bookingId: String, paymentId: String) -> Result<Void, CheckInError> {
        if case .failure(let error) = canCheckIn(bookingId: bookingId) { return .failure(error) }
        guard let index = storage.firstIndex(where: { $0.id == bookingId }),
              let machine = MockMachines.stored.first(where: { $0.id == storage[index].machineId }) else {
            return .failure(.notReady)
        }

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(machine.cycleMinutes * 60))
        storage[index].status = .inProgress
        storage[index].startTime = start
        storage[index].endTime = end
        storage[index].holdExpiresAt = nil
        storage[index].paymentId = paymentId
        MockMachines.update(machine.id) {
            $0.status = .inUse
            $0.availableAt = end
        }
        // A late check-in can run into the next booking, whose hold must not run out while it waits
        extendHolds(machineId: machine.id, until: end)
        commit()
        return .success(())
    }

    /// Cancels a reservation or a later booking that has not been checked in. It is free.
    static func cancelReservation(bookingId: String) {
        advance()
        guard let index = storage.firstIndex(where: { $0.id == bookingId }),
              storage[index].status == .confirmed, storage[index].holdExpiresAt != nil else { return }
        storage[index].status = .cancelled
        storage[index].holdExpiresAt = nil
        release(machine: storage[index].machineId, from: .reserved)
        commit()
    }

    /// Applies what happens as time passes: holds wait for a machine that is still busy, holds that ran out
    /// expire, finished cycles complete, a booking whose start time has come holds its machine,
    /// and a machine nobody holds is released.
    static func advance() {
        let current = Date()
        var changed = false

        // A busy machine delays the bookings waiting for it, so their check-in window starts when it frees up
        for machine in MockMachines.stored where machine.status == .inUse {
            if let free = machine.availableAt, extendHolds(machineId: machine.id, until: free) { changed = true }
        }

        for index in storage.indices {
            switch storage[index].status {
            case .confirmed:
                if let deadline = storage[index].holdExpiresAt, deadline < current {
                    storage[index].status = .expired
                    storage[index].holdExpiresAt = nil
                    release(machine: storage[index].machineId, from: .reserved)
                    changed = true
                }
            case .inProgress:
                if storage[index].endTime < current {
                    storage[index].status = .completed
                    release(machine: storage[index].machineId, from: .inUse)
                    changed = true
                }
            default:
                break
            }
        }

        // Cycles by people without a booking in the app
        for machine in MockMachines.stored where machine.status == .inUse {
            guard let free = machine.availableAt, free < current,
                  !storage.contains(where: { $0.machineId == machine.id && $0.status == .inProgress }) else { continue }
            MockMachines.update(machine.id) {
                $0.status = .available
                $0.availableAt = nil
            }
        }

        for booking in storage where isHeld(booking) {
            if MockMachines.stored.first(where: { $0.id == booking.machineId })?.status == .available {
                MockMachines.update(booking.machineId) { $0.status = .reserved }
            }
        }

        // Only a booking can hold a machine, so a "reserved" machine without one is released
        for machine in MockMachines.stored where machine.status == .reserved {
            if !storage.contains(where: { $0.machineId == machine.id && isHeld($0) }) {
                MockMachines.update(machine.id) {
                    $0.status = .available
                    $0.availableAt = nil
                }
            }
        }

        // The first call also clears plans left behind by earlier versions
        if changed || !didPrunePlans {
            let live = storage.filter { $0.status == .confirmed || $0.status == .inProgress }
            ArrivalPlanStore.shared.prune(keeping: Set(live.map(\.id)))
            didPrunePlans = true
        }

        if changed || MockMachines.isDirty { commit() }
    }

    /// Replaces the saved data. For tests.
    static func reset(bookings: [Booking], machines: [Machine]) {
        storage = bookings
        MockMachines.stored = machines
        MockMachines.isDirty = false
        didPrunePlans = false
    }

    // MARK: - Helpers
    private static var didPrunePlans = false

    /// Gives bookings waiting for a busy machine a full check-in window once it frees up,
    /// but never more than `maxWaitMinutes` past their start. Returns whether anything changed.
    @discardableResult
    private static func extendHolds(machineId: String, until free: Date) -> Bool {
        var changed = false
        for index in storage.indices {
            let booking = storage[index]
            guard booking.machineId == machineId, booking.status == .confirmed,
                  let deadline = booking.holdExpiresAt, booking.startTime < free else { continue }
            let longest = booking.startTime.addingTimeInterval(TimeInterval((maxWaitMinutes + holdMinutes) * 60))
            let extended = min(free.addingTimeInterval(TimeInterval(holdMinutes * 60)), longest)
            if extended > deadline {
                storage[index].holdExpiresAt = extended
                changed = true
            }
        }
        return changed
    }

    private static func commit() {
        MockStore.save(storage, key: MockStore.bookingsKey)
        MockStore.save(MockMachines.stored, key: MockStore.machinesKey)
        MockMachines.isDirty = false
    }

    /// Frees the machine only if it is still in the state this booking left it in
    private static func release(machine id: String, from status: MachineStatus) {
        guard MockMachines.stored.first(where: { $0.id == id })?.status == status else { return }
        MockMachines.update(id) {
            $0.status = .available
            $0.availableAt = nil
        }
    }

    private static func hours(on day: Date) -> (open: Date, close: Date) {
        let start = calendar.startOfDay(for: day)
        let open = calendar.date(bySettingHour: openingHour, minute: 0, second: 0, of: start) ?? start
        let close = calendar.date(bySettingHour: closingHour, minute: 0, second: 0, of: start) ?? start
        return (open, close)
    }

    /// Whether the machine is free for a whole cycle starting at `start`
    private static func canBook(_ machine: Machine, start: Date) -> Bool {
        guard machine.status != .outOfOrder else { return false }
        let cycle = TimeInterval(machine.cycleMinutes * 60)
        let end = start.addingTimeInterval(cycle)

        let (open, close) = hours(on: start)
        guard start >= open, end <= close, start >= Date().addingTimeInterval(-60) else { return false }

        if machine.status == .inUse {
            let busyUntil = machine.availableAt ?? Date().addingTimeInterval(cycle)
            if start < busyUntil { return false }
        }
        let active: [BookingStatus] = [.pending, .confirmed, .inProgress]
        return !storage.contains { booking in
            booking.machineId == machine.id && active.contains(booking.status)
                && booking.startTime < end && start < booking.endTime
        }
    }

    private static func minutes(_ offset: Int) -> Date {
        launch.addingTimeInterval(TimeInterval(offset * 60))
    }

    private static func day(_ offset: Int, hour: Int) -> Date {
        let base = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: launch)) ?? launch
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
    }

    // Price, laundromat and cycle length come from the machine, so they always match
    private static func make(_ id: String, machine machineId: String, start: Date, status: BookingStatus) -> Booking {
        guard let machine = MockMachines.stored.first(where: { $0.id == machineId }) else {
            preconditionFailure("MockBooking refers to unknown machine \(machineId)")
        }
        return Booking(id: id,
                       userId: MockUser.current.id,
                       laundromatId: machine.laundromatId,
                       machineId: machine.id,
                       startTime: start,
                       endTime: start.addingTimeInterval(TimeInterval(machine.cycleMinutes * 60)),
                       status: status,
                       totalPrice: machine.pricePerCycle,
                       paymentId: status == .pending || status == .cancelled ? nil : "pay-\(id)",
                       createdAt: start.addingTimeInterval(-24 * 3600),
                       holdExpiresAt: status == .confirmed ? start.addingTimeInterval(TimeInterval(holdMinutes * 60)) : nil)
    }
}
