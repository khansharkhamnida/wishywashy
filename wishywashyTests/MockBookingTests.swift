//
//  MockBookingTests.swift
//  wishywashyTests
//

import Foundation
import Testing
@testable import wishywashy

@Suite(.serialized)
final class MockBookingTests {
    private let suiteName = "MockBookingTests-\(UUID().uuidString)"
    private let minute: TimeInterval = 60

    init() {
        MockStore.defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        MockStore.defaults.removePersistentDomain(forName: suiteName)
        MockStore.defaults = .standard
        MockBooking.reset(bookings: [], machines: [])
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
        try #require(MockBooking.all.first { $0.id == id })
    }

    // MARK: - Holds wait for a busy machine
    @Test func holdWaitsForBusyMachine() throws {
        let now = Date()
        let free = now.addingTimeInterval(5 * minute)
        // The hold already ran out, but the machine is still busy for 5 more minutes
        MockBooking.reset(
            bookings: [booking("b", start: now.addingTimeInterval(-12 * minute), holdUntil: now.addingTimeInterval(-2 * minute))],
            machines: [machine(status: .inUse, availableAt: free)])

        let result = try current("b")
        #expect(result.status == .confirmed)
        let deadline = try #require(result.holdExpiresAt)
        #expect(abs(deadline.timeIntervalSince(free) - Double(MockBooking.holdMinutes) * minute) < 1)
    }

    @Test func holdStartsWhenMachineFrees() throws {
        let now = Date()
        // The previous cycle finished a minute ago; the user gets a full window from then
        MockBooking.reset(
            bookings: [booking("b", start: now.addingTimeInterval(-12 * minute), holdUntil: now.addingTimeInterval(-2 * minute))],
            machines: [machine(status: .inUse, availableAt: now.addingTimeInterval(-minute))])

        let result = try current("b")
        #expect(result.status == .confirmed)
        #expect(MockMachines.stored.first?.status == .reserved)
    }

    @Test func waitIsCapped() throws {
        let now = Date()
        let start = now.addingTimeInterval(-5 * minute)
        MockBooking.reset(
            bookings: [booking("b", start: start, holdUntil: start.addingTimeInterval(10 * minute))],
            machines: [machine(status: .inUse, availableAt: now.addingTimeInterval(120 * minute))])

        let deadline = try #require(try current("b").holdExpiresAt)
        let longest = start.addingTimeInterval(Double(MockBooking.maxWaitMinutes + MockBooking.holdMinutes) * minute)
        #expect(abs(deadline.timeIntervalSince(longest)) < 1)
    }

    @Test func holdWithoutBusyMachineStillExpires() throws {
        let now = Date()
        MockBooking.reset(
            bookings: [booking("b", start: now.addingTimeInterval(-12 * minute), holdUntil: now.addingTimeInterval(-2 * minute))],
            machines: [machine(status: .reserved)])

        #expect(try current("b").status == .expired)
        #expect(MockMachines.stored.first?.status == .available)
    }

    @Test func lateCheckInExtendsNextBookingsHold() throws {
        let now = Date()
        let next = now.addingTimeInterval(20 * minute)
        MockBooking.reset(
            bookings: [booking("a", start: now.addingTimeInterval(-minute), holdUntil: now.addingTimeInterval(9 * minute)),
                       booking("b", start: next, holdUntil: next.addingTimeInterval(10 * minute))],
            machines: [machine(status: .reserved)])

        guard case .success = MockBooking.checkIn(bookingId: "a", paymentId: "p") else {
            Issue.record("check-in failed")
            return
        }
        let first = try current("a")
        let second = try current("b")
        let expected = first.endTime.addingTimeInterval(Double(MockBooking.holdMinutes) * minute)
        #expect(abs(try #require(second.holdExpiresAt).timeIntervalSince(expected)) < 1)
    }

    // MARK: - Booking rules
    private func twoFreeMachines() -> [Machine] {
        [machine("m1", status: .available), machine("m2", status: .available)]
    }

    @Test func reserveNowOnFreeMachineSucceeds() throws {
        MockBooking.reset(bookings: [], machines: twoFreeMachines())

        let booking = try MockBooking.book(machineId: "m1", start: nil).get()

        #expect(booking.status == .confirmed)
        #expect(MockMachines.all.first { $0.id == "m1" }?.status == .reserved)
    }

    @Test func onlyOneReservationCanWaitForCheckIn() throws {
        MockBooking.reset(bookings: [], machines: twoFreeMachines())
        _ = try MockBooking.book(machineId: "m1", start: nil).get()

        let second = MockBooking.book(machineId: "m2", start: nil)

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
        MockBooking.reset(bookings: [], machines: [machine(status: .available)])

        for time in times.prefix(MockBooking.maxUpcoming) {
            _ = try MockBooking.book(machineId: "m1", start: time).get()
        }
        let sixth = MockBooking.book(machineId: "m1", start: times[5])

        guard case .failure(.tooManyBookings) = sixth else {
            Issue.record("expected tooManyBookings")
            return
        }
    }

    @Test func overlappingSlotIsRefused() throws {
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 3600))
        let ten = tomorrow.addingTimeInterval(10 * 3600)
        MockBooking.reset(bookings: [], machines: [machine(status: .available)])
        _ = try MockBooking.book(machineId: "m1", start: ten).get()

        // The 30 minute cycle from 10:00 is still running at 10:15
        let overlap = MockBooking.book(machineId: "m1", start: ten.addingTimeInterval(15 * minute))

        guard case .failure(.slotTaken) = overlap else {
            Issue.record("expected slotTaken")
            return
        }
    }

    @Test func outOfOrderMachineCannotBeBooked() {
        MockBooking.reset(bookings: [], machines: [machine(status: .outOfOrder)])

        guard case .failure(.machineUnavailable) = MockBooking.book(machineId: "m1", start: nil) else {
            Issue.record("expected machineUnavailable")
            return
        }
        #expect(MockBooking.nowStart(for: "m1") == nil)
    }

    @Test func busyMachineFreeingLaterThanFifteenMinutesCannotBeReservedNow() {
        let now = Date()
        MockBooking.reset(bookings: [], machines: [
            machine("soon", status: .inUse, availableAt: now.addingTimeInterval(5 * minute)),
            machine("late", status: .inUse, availableAt: now.addingTimeInterval(18 * minute))])

        #expect(MockBooking.nowStart(for: "soon") != nil)
        #expect(MockBooking.nowStart(for: "late") == nil)
    }

    // MARK: - Check-in
    @Test func cannotCheckInBeforeStartTime() throws {
        MockBooking.reset(bookings: [], machines: [machine(status: .available)])
        let start = Date().addingTimeInterval(60 * minute)
        let booking = try MockBooking.book(machineId: "m1", start: start).get()

        guard case .failure(.notReady) = MockBooking.canCheckIn(bookingId: booking.id) else {
            Issue.record("expected notReady")
            return
        }
    }

    @Test func cannotCheckInWhilePreviousUserIsStillThere() {
        let now = Date()
        MockBooking.reset(
            bookings: [booking("b", start: now.addingTimeInterval(-minute), holdUntil: now.addingTimeInterval(9 * minute))],
            machines: [machine(status: .inUse, availableAt: now.addingTimeInterval(3 * minute))])

        guard case .failure(.machineBusy) = MockBooking.canCheckIn(bookingId: "b") else {
            Issue.record("expected machineBusy")
            return
        }
    }

    @Test func checkInStartsTheCycleAndCancelFreesTheMachine() throws {
        MockBooking.reset(bookings: [], machines: [machine(status: .available)])
        let booking = try MockBooking.book(machineId: "m1", start: nil).get()

        try MockBooking.checkIn(bookingId: booking.id, paymentId: "p1").get()
        #expect(try current(booking.id).status == .inProgress)
        #expect(MockMachines.all.first?.status == .inUse)

        // Only a booking that has not been checked in can be cancelled
        MockBooking.cancelReservation(bookingId: booking.id)
        #expect(try current(booking.id).status == .inProgress)
    }

    @Test func cancellingAReservationReleasesTheMachine() throws {
        MockBooking.reset(bookings: [], machines: [machine(status: .available)])
        let booking = try MockBooking.book(machineId: "m1", start: nil).get()

        MockBooking.cancelReservation(bookingId: booking.id)

        #expect(try current(booking.id).status == .cancelled)
        #expect(MockMachines.all.first?.status == .available)
    }

    // MARK: - Reserved machines
    @Test func reservedMachineWithoutBookingIsReleased() {
        MockBooking.reset(bookings: [], machines: [machine(status: .reserved)])
        #expect(MockMachines.all.first?.status == .available)
    }

    @Test func reservedMachineWithHeldBookingStaysReserved() {
        let now = Date()
        MockBooking.reset(
            bookings: [booking("b", start: now.addingTimeInterval(-minute), holdUntil: now.addingTimeInterval(9 * minute))],
            machines: [machine(status: .reserved)])
        #expect(MockMachines.all.first?.status == .reserved)
    }

    // MARK: - Arrival plans
    private func plan(for bookingId: String) -> ArrivalPlan {
        ArrivalPlan(bookingId: bookingId, arriveBy: Date(), travelMinutes: 10, bufferMinutes: 5,
                    mode: .walking, isManualEstimate: false, reminderOn: false)
    }

    @Test func expiredBookingRemovesItsPlan() {
        let now = Date()
        MockBooking.reset(
            bookings: [booking("t-expired", start: now.addingTimeInterval(-30 * minute), holdUntil: now.addingTimeInterval(-20 * minute)),
                       booking("t-live", start: now.addingTimeInterval(60 * minute), holdUntil: now.addingTimeInterval(70 * minute))],
            machines: [machine(status: .available)])
        let store = ArrivalPlanStore.shared
        store.save(plan(for: "t-expired"))
        store.save(plan(for: "t-live"))
        defer { store.remove(bookingId: "t-expired"); store.remove(bookingId: "t-live") }

        _ = MockBooking.all

        #expect(store.plan(for: "t-expired") == nil)
        #expect(store.plan(for: "t-live") != nil)
    }
}
