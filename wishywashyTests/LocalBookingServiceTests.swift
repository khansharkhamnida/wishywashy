//
//  LocalBookingServiceTests.swift
//  wishywashyTests
//

import Foundation
import Testing
@testable import wishywashy

final class LocalBookingServiceTests {
    private let suiteName = "LocalBookingServiceTests-\(UUID().uuidString)"
    private let minute: TimeInterval = 60
    private let store: LocalStore
    private let plans: ArrivalPlanStore
    private var service: LocalBookingService

    init() {
        store = LocalStore(defaults: UserDefaults(suiteName: suiteName)!)
        plans = ArrivalPlanStore(store: store)
        service = LocalBookingService(machines: [], bookings: [], store: store, plans: plans)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    /// Starts a fresh service with this data, saving to a throwaway suite
    private func load(bookings: [Booking], machines: [Machine]) {
        service = LocalBookingService(machines: machines, bookings: bookings, store: store, plans: plans)
    }

    private func machine(_ id: String = "m1", status: MachineStatus, availableAt: Date? = nil) -> Machine {
        Machine(id: id, laundromatId: "l1", type: .washer, label: id.uppercased(),
                capacityKg: 10, status: status, pricePerCycle: 5, cycleMinutes: 30, availableAt: availableAt)
    }

    private func booking(_ id: String, machine: String = "m1", start: Date,
                         status: BookingStatus = .confirmed, holdUntil: Date? = nil) -> Booking {
        Booking(id: id, userId: "u", laundromatId: "l1", machineId: machine,
                startTime: start, endTime: start.addingTimeInterval(30 * minute),
                status: status, totalPrice: 5, paymentId: nil, createdAt: start,
                holdExpiresAt: holdUntil)
    }

    private func current(_ id: String) throws -> Booking {
        try #require(service.bookings.first { $0.id == id })
    }

    // MARK: - Holds wait for a busy machine
    @Test func holdWaitsForBusyMachine() throws {
        let now = Date()
        let free = now.addingTimeInterval(5 * minute)
        // The hold already ran out, but the machine is still busy for 5 more minutes
        load(
            bookings: [booking("b", start: now.addingTimeInterval(-12 * minute), holdUntil: now.addingTimeInterval(-2 * minute))],
            machines: [machine(status: .inUse, availableAt: free)])

        let result = try current("b")
        #expect(result.status == .confirmed)
        let deadline = try #require(result.holdExpiresAt)
        #expect(abs(deadline.timeIntervalSince(free) - Double(BookingRules.holdMinutes) * minute) < 1)
    }

    @Test func holdStartsWhenMachineFrees() throws {
        let now = Date()
        // The previous cycle finished a minute ago; the user gets a full window from then
        load(
            bookings: [booking("b", start: now.addingTimeInterval(-12 * minute), holdUntil: now.addingTimeInterval(-2 * minute))],
            machines: [machine(status: .inUse, availableAt: now.addingTimeInterval(-minute))])

        let result = try current("b")
        #expect(result.status == .confirmed)
        #expect(service.machine(id: "m1")?.status == .reserved)
    }

    @Test func waitIsCapped() throws {
        let now = Date()
        let start = now.addingTimeInterval(-5 * minute)
        load(
            bookings: [booking("b", start: start, holdUntil: start.addingTimeInterval(10 * minute))],
            machines: [machine(status: .inUse, availableAt: now.addingTimeInterval(120 * minute))])

        let deadline = try #require(try current("b").holdExpiresAt)
        let longest = start.addingTimeInterval(Double(BookingRules.maxWaitMinutes + BookingRules.holdMinutes) * minute)
        #expect(abs(deadline.timeIntervalSince(longest)) < 1)
    }

    @Test func holdWithoutBusyMachineStillExpires() throws {
        let now = Date()
        load(
            bookings: [booking("b", start: now.addingTimeInterval(-12 * minute), holdUntil: now.addingTimeInterval(-2 * minute))],
            machines: [machine(status: .reserved)])

        #expect(try current("b").status == .expired)
        #expect(service.machine(id: "m1")?.status == .available)
    }

    @Test func lateCheckInExtendsNextBookingsHold() throws {
        let now = Date()
        let next = now.addingTimeInterval(20 * minute)
        load(
            bookings: [booking("a", start: now.addingTimeInterval(-minute), holdUntil: now.addingTimeInterval(9 * minute)),
                       booking("b", start: next, holdUntil: next.addingTimeInterval(10 * minute))],
            machines: [machine(status: .reserved)])

        guard case .success = service.checkIn(bookingId: "a", paymentId: "p") else {
            Issue.record("check-in failed")
            return
        }
        let first = try current("a")
        let second = try current("b")
        let expected = first.endTime.addingTimeInterval(Double(BookingRules.holdMinutes) * minute)
        #expect(abs(try #require(second.holdExpiresAt).timeIntervalSince(expected)) < 1)
    }

    // MARK: - Booking rules
    private func twoFreeMachines() -> [Machine] {
        [machine("m1", status: .available), machine("m2", status: .available)]
    }

    @Test func reserveNowOnFreeMachineSucceeds() throws {
        load(bookings: [], machines: twoFreeMachines())

        let booking = try service.book(machineId: "m1", start: nil).get()

        #expect(booking.status == .confirmed)
        #expect(service.machine(id: "m1")?.status == .reserved)
    }

    @Test func onlyOneReservationCanWaitForCheckIn() throws {
        load(bookings: [], machines: twoFreeMachines())
        _ = try service.book(machineId: "m1", start: nil).get()

        let second = service.book(machineId: "m2", start: nil)

        #expect(throws: ReserveError.self) { try second.get() }
        guard case .failure(.alreadyHolding) = second else {
            Issue.record("expected alreadyHolding")
            return
        }
    }

    @Test func sixthUpcomingBookingIsRefused() throws {
        let day = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let tomorrow = Calendar.current.startOfDay(for: day)
        let times = (0..<6).map { tomorrow.addingTimeInterval(Double(8 + $0 * 2) * 3600) }
        load(bookings: [], machines: [machine(status: .available)])

        for time in times.prefix(BookingRules.maxUpcoming) {
            _ = try service.book(machineId: "m1", start: time).get()
        }
        let sixth = service.book(machineId: "m1", start: times[5])

        guard case .failure(.tooManyBookings) = sixth else {
            Issue.record("expected tooManyBookings")
            return
        }
    }

    @Test func overlappingSlotIsRefused() throws {
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 3600))
        let ten = tomorrow.addingTimeInterval(10 * 3600)
        load(bookings: [], machines: [machine(status: .available)])
        _ = try service.book(machineId: "m1", start: ten).get()

        // The 30 minute cycle from 10:00 is still running at 10:15
        let overlap = service.book(machineId: "m1", start: ten.addingTimeInterval(15 * minute))

        guard case .failure(.slotTaken) = overlap else {
            Issue.record("expected slotTaken")
            return
        }
    }

    @Test func outOfOrderMachineCannotBeBooked() {
        load(bookings: [], machines: [machine(status: .outOfOrder)])

        guard case .failure(.machineUnavailable) = service.book(machineId: "m1", start: nil) else {
            Issue.record("expected machineUnavailable")
            return
        }
        #expect(service.nowStart(for: "m1") == nil)
    }

    @Test func busyMachineFreeingLaterThanFifteenMinutesCannotBeReservedNow() {
        let now = Date()
        load(bookings: [], machines: [
            machine("soon", status: .inUse, availableAt: now.addingTimeInterval(5 * minute)),
            machine("late", status: .inUse, availableAt: now.addingTimeInterval(18 * minute))])

        #expect(service.nowStart(for: "soon") != nil)
        #expect(service.nowStart(for: "late") == nil)
    }

    // MARK: - Check-in
    @Test func cannotCheckInBeforeStartTime() throws {
        load(bookings: [], machines: [machine(status: .available)])
        let start = Date().addingTimeInterval(60 * minute)
        let booking = try service.book(machineId: "m1", start: start).get()

        guard case .failure(.notReady) = service.canCheckIn(bookingId: booking.id) else {
            Issue.record("expected notReady")
            return
        }
    }

    @Test func cannotCheckInWhilePreviousUserIsStillThere() {
        let now = Date()
        load(
            bookings: [booking("b", start: now.addingTimeInterval(-minute), holdUntil: now.addingTimeInterval(9 * minute))],
            machines: [machine(status: .inUse, availableAt: now.addingTimeInterval(3 * minute))])

        guard case .failure(.machineBusy) = service.canCheckIn(bookingId: "b") else {
            Issue.record("expected machineBusy")
            return
        }
    }

    @Test func checkInStartsTheCycleAndCancelFreesTheMachine() throws {
        load(bookings: [], machines: [machine(status: .available)])
        let booking = try service.book(machineId: "m1", start: nil).get()

        try service.checkIn(bookingId: booking.id, paymentId: "p1").get()
        #expect(try current(booking.id).status == .inProgress)
        #expect(service.machine(id: "m1")?.status == .inUse)

        // Only a booking that has not been checked in can be cancelled
        service.cancelReservation(bookingId: booking.id)
        #expect(try current(booking.id).status == .inProgress)
    }

    @Test func cancellingAReservationReleasesTheMachine() throws {
        load(bookings: [], machines: [machine(status: .available)])
        let booking = try service.book(machineId: "m1", start: nil).get()

        service.cancelReservation(bookingId: booking.id)

        #expect(try current(booking.id).status == .cancelled)
        #expect(service.machine(id: "m1")?.status == .available)
    }

    // MARK: - Reserved machines
    @Test func reservedMachineWithoutBookingIsReleased() {
        load(bookings: [], machines: [machine(status: .reserved)])
        #expect(service.machine(id: "m1")?.status == .available)
    }

    @Test func reservedMachineWithHeldBookingStaysReserved() {
        let now = Date()
        load(
            bookings: [booking("b", start: now.addingTimeInterval(-minute), holdUntil: now.addingTimeInterval(9 * minute))],
            machines: [machine(status: .reserved)])
        #expect(service.machine(id: "m1")?.status == .reserved)
    }

    // MARK: - Arrival plans
    private func plan(for bookingId: String) -> ArrivalPlan {
        ArrivalPlan(bookingId: bookingId, arriveBy: Date(), travelMinutes: 10, bufferMinutes: 5,
                    mode: .walking, isManualEstimate: false, reminderOn: false)
    }

    @Test func expiredBookingRemovesItsPlan() {
        let now = Date()
        load(
            bookings: [booking("t-expired", start: now.addingTimeInterval(-30 * minute), holdUntil: now.addingTimeInterval(-20 * minute)),
                       booking("t-live", start: now.addingTimeInterval(60 * minute), holdUntil: now.addingTimeInterval(70 * minute))],
            machines: [machine(status: .available)])
        let store = plans
        store.save(plan(for: "t-expired"))
        store.save(plan(for: "t-live"))
        defer { store.remove(bookingId: "t-expired"); store.remove(bookingId: "t-live") }

        _ = service.bookings

        #expect(store.plan(for: "t-expired") == nil)
        #expect(store.plan(for: "t-live") != nil)
    }
}
