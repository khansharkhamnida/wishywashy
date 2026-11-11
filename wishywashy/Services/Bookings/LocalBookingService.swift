//
//  LocalBookingService.swift
//  wishywashy
//
//  Answers booking questions on the device, until there is a server.
//  It plays the part of the server: it applies the booking rules (see `BookingRules`),
//  keeps time moving for machines and bookings, and saves everything on the device.
//
//  A booking is `confirmed` with a `holdExpiresAt`. From its start time the user has
//  `BookingRules.holdMinutes` to check in. If they do not, it expires and the machine is released.
//

import Foundation

final class LocalBookingService: BookingService {
    private var storage: [Booking]
    private var machineList: [Machine]
    private var machinesChanged = false
    private var didPrunePlans = false

    private let store: LocalStore
    private let plans: ArrivalPlanStore
    private let laundromats: [Laundromat]
    private let user: User
    private let calendar = Calendar.current

    init(machines: [Machine],
         bookings: [Booking],
         store: LocalStore = .shared,
         plans: ArrivalPlanStore = .shared,
         laundromats: [Laundromat] = PartnerLaundromats.all,
         user: User = Session.user) {
        self.machineList = machines
        self.storage = bookings
        self.store = store
        self.plans = plans
        self.laundromats = laundromats
        self.user = user
    }

    /// Starts from what is saved on the device, or from the sample data the first time
    convenience init(store: LocalStore = .shared, plans: ArrivalPlanStore = .shared) {
        let machines = store.load([Machine].self, key: StoreKey.machines) ?? SampleMachines.make()
        let bookings = store.load([Booking].self, key: StoreKey.bookings) ?? SampleBookings.make(machines: machines)
        self.init(machines: machines, bookings: bookings, store: store, plans: plans)
    }

    // MARK: - Reading
    var bookings: [Booking] {
        advance()
        return storage
    }

    var details: [BookingDetail] {
        bookings.map { booking in
            BookingDetail(booking: booking,
                          machine: machineList.first { $0.id == booking.machineId },
                          laundromat: laundromats.first { $0.id == booking.laundromatId })
        }
    }

    func machines(inLaundromat laundromatId: String) -> [Machine] {
        advance()
        return machineList.filter { $0.laundromatId == laundromatId }
    }

    func machine(id: String) -> Machine? {
        advance()
        return machineList.first { $0.id == id }
    }

    // MARK: - Availability
    /// When the user could start if they reserve "now": straight away for a free machine,
    /// or when a busy one frees up, if that is soon. Nil if it cannot be reserved now.
    func nowStart(for machineId: String) -> Date? {
        advance()
        guard let machine = machineList.first(where: { $0.id == machineId }) else { return nil }
        let now = Date()
        let candidate: Date
        switch machine.status {
        case .available:
            candidate = now
        case .inUse:
            guard let free = machine.availableAt,
                  free.timeIntervalSince(now) <= TimeInterval(BookingRules.finishingSoonMinutes * 60) else { return nil }
            candidate = max(free, now)
        case .reserved, .outOfOrder:
            return nil
        }
        return canBook(machine, start: candidate) ? candidate : nil
    }

    func slots(machineId: String, dayOffset: Int) -> [Date] {
        advance()
        guard let machine = machineList.first(where: { $0.id == machineId }),
              let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) else { return [] }
        let (open, close) = hours(on: day)
        var result: [Date] = []
        var time = open
        while time < close {
            if time > Date(), canBook(machine, start: time) { result.append(time) }
            time = time.addingTimeInterval(TimeInterval(BookingRules.slotStepMinutes * 60))
        }
        return result
    }

    // MARK: - Changes
    func book(machineId: String, start: Date?) -> Result<Booking, ReserveError> {
        advance()
        guard let machine = machineList.first(where: { $0.id == machineId }) else {
            return .failure(.machineUnavailable)
        }
        let begin: Date
        if let start {
            begin = start
        } else {
            // One reservation at a time can be waiting for check-in, so nobody blocks several machines
            if storage.contains(where: \.isHeld) { return .failure(.alreadyHolding) }
            guard let soonest = nowStart(for: machineId) else { return .failure(.machineUnavailable) }
            begin = soonest
        }
        if storage.filter(\.isActiveReservation).count >= BookingRules.maxUpcoming { return .failure(.tooManyBookings) }
        guard canBook(machine, start: begin) else {
            return .failure(start == nil ? .machineUnavailable : .slotTaken)
        }

        let booking = Booking(id: "b\(UUID().uuidString.prefix(8))",
                              userId: user.id,
                              laundromatId: machine.laundromatId,
                              machineId: machine.id,
                              startTime: begin,
                              endTime: begin.addingTimeInterval(TimeInterval(machine.cycleMinutes * 60)),
                              status: .confirmed,
                              totalPrice: machine.pricePerCycle,
                              paymentId: nil,
                              createdAt: Date(),
                              holdExpiresAt: begin.addingTimeInterval(TimeInterval(BookingRules.holdMinutes * 60)))
        storage.append(booking)
        advance()
        commit()
        return .success(booking)
    }

    func canCheckIn(bookingId: String) -> Result<Booking, CheckInError> {
        advance()
        guard let booking = storage.first(where: { $0.id == bookingId }), booking.isHeld,
              let machine = machineList.first(where: { $0.id == booking.machineId }) else {
            return .failure(.notReady)
        }
        // The machine only turns "reserved" once the previous user has left
        guard machine.status == .reserved else { return .failure(.machineBusy) }
        return .success(booking)
    }

    func checkIn(bookingId: String, paymentId: String) -> Result<Void, CheckInError> {
        if case .failure(let error) = canCheckIn(bookingId: bookingId) { return .failure(error) }
        guard let index = storage.firstIndex(where: { $0.id == bookingId }),
              let machine = machineList.first(where: { $0.id == storage[index].machineId }) else {
            return .failure(.notReady)
        }

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(machine.cycleMinutes * 60))
        storage[index].status = .inProgress
        storage[index].startTime = start
        storage[index].endTime = end
        storage[index].holdExpiresAt = nil
        storage[index].paymentId = paymentId
        updateMachine(machine.id) {
            $0.status = .inUse
            $0.availableAt = end
        }
        // A late check-in can run into the next booking, whose hold must not run out while it waits
        extendHolds(machineId: machine.id, until: end)
        commit()
        return .success(())
    }

    func cancelReservation(bookingId: String) {
        advance()
        guard let index = storage.firstIndex(where: { $0.id == bookingId }),
              storage[index].isActiveReservation else { return }
        storage[index].status = .cancelled
        storage[index].holdExpiresAt = nil
        release(machine: storage[index].machineId, from: .reserved)
        commit()
    }

    // MARK: - Time passing
    /// Applies what happens as time passes: holds wait for a machine that is still busy, holds that ran out
    /// expire, finished cycles complete, a booking whose start time has come holds its machine,
    /// and a machine nobody holds is released.
    private func advance() {
        let current = Date()
        var changed = false

        // A busy machine delays the bookings waiting for it, so their check-in window starts when it frees up
        for machine in machineList where machine.status == .inUse {
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
        for machine in machineList where machine.status == .inUse {
            guard let free = machine.availableAt, free < current,
                  !storage.contains(where: { $0.machineId == machine.id && $0.status == .inProgress }) else { continue }
            updateMachine(machine.id) {
                $0.status = .available
                $0.availableAt = nil
            }
        }

        for booking in storage where booking.isHeld {
            if machineList.first(where: { $0.id == booking.machineId })?.status == .available {
                updateMachine(booking.machineId) { $0.status = .reserved }
            }
        }

        // Only a booking can hold a machine, so a "reserved" machine without one is released
        for machine in machineList where machine.status == .reserved {
            if !storage.contains(where: { $0.machineId == machine.id && $0.isHeld }) {
                updateMachine(machine.id) {
                    $0.status = .available
                    $0.availableAt = nil
                }
            }
        }

        // The first call also clears plans left behind by earlier versions
        if changed || !didPrunePlans {
            let live = storage.filter { $0.status == .confirmed || $0.status == .inProgress }
            plans.prune(keeping: Set(live.map(\.id)))
            didPrunePlans = true
        }

        if changed || machinesChanged { commit() }
    }

    /// Gives bookings waiting for a busy machine a full check-in window once it frees up,
    /// but never more than `maxWaitMinutes` past their start. Returns whether anything changed.
    @discardableResult
    private func extendHolds(machineId: String, until free: Date) -> Bool {
        var changed = false
        for index in storage.indices {
            let booking = storage[index]
            guard booking.machineId == machineId, booking.isActiveReservation,
                  let deadline = booking.holdExpiresAt, booking.startTime < free else { continue }
            let longest = booking.startTime.addingTimeInterval(
                TimeInterval((BookingRules.maxWaitMinutes + BookingRules.holdMinutes) * 60))
            let extended = min(free.addingTimeInterval(TimeInterval(BookingRules.holdMinutes * 60)), longest)
            if extended > deadline {
                storage[index].holdExpiresAt = extended
                changed = true
            }
        }
        return changed
    }

    // MARK: - Helpers
    private func commit() {
        store.save(storage, key: StoreKey.bookings)
        store.save(machineList, key: StoreKey.machines)
        machinesChanged = false
    }

    private func updateMachine(_ id: String, _ change: (inout Machine) -> Void) {
        guard let index = machineList.firstIndex(where: { $0.id == id }) else { return }
        change(&machineList[index])
        machinesChanged = true
    }

    /// Frees the machine only if it is still in the state this booking left it in
    private func release(machine id: String, from status: MachineStatus) {
        guard machineList.first(where: { $0.id == id })?.status == status else { return }
        updateMachine(id) {
            $0.status = .available
            $0.availableAt = nil
        }
    }

    private func hours(on day: Date) -> (open: Date, close: Date) {
        let start = calendar.startOfDay(for: day)
        let open = calendar.date(bySettingHour: BookingRules.openingHour, minute: 0, second: 0, of: start) ?? start
        let close = calendar.date(bySettingHour: BookingRules.closingHour, minute: 0, second: 0, of: start) ?? start
        return (open, close)
    }

    /// Whether the machine is free for a whole cycle starting at `start`
    private func canBook(_ machine: Machine, start: Date) -> Bool {
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
}
