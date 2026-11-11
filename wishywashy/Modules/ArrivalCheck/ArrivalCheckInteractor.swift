//
//  ArrivalCheckInteractor.swift
//  wishywashy
//

import CoreLocation
import Foundation

final class ArrivalCheckInteractor: ArrivalCheckInteractorInputProtocol {
    weak var output: ArrivalCheckInteractorOutputProtocol?

    private let bookingId: String
    private let store = ArrivalPlanStore.shared
    private let bookings: BookingService
    private var task: Task<Void, Never>?

    init(bookingId: String, bookings: BookingService = Services.bookings) {
        self.bookingId = bookingId
        self.bookings = bookings
    }

    // MARK: - Input
    func loadBooking() {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            guard let detail = activeBooking() else {
                output?.didFail(message: "This booking is no longer active.")
                return
            }
            output?.didLoadBooking(ArrivalBookingInfo(detail: detail,
                                                      checkInDeadline: checkInDeadline(for: detail.booking),
                                                      plan: store.plan(for: bookingId),
                                                      notificationPermission: await NotificationService.shared.permission(),
                                                      remindersAllowed: remindersAllowed))
        }
    }

    func checkWithCurrentLocation(mode: TravelMode) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self, let detail = activeBooking() else { return }

            if LocationService.shared.permission == .denied {
                output?.didNeedManualInput(message: "Location is off, so we can't work out the trip for you. Tell us where you're starting from, or how long it takes.")
                return
            }
            // One-off request: the location is used once and not kept
            guard let origin = await LocationService.shared.currentLocation() else {
                if !Task.isCancelled {
                    output?.didNeedManualInput(message: "We couldn't get your location. Tell us where you're starting from, or how long it takes.")
                }
                return
            }
            await estimate(from: origin, mode: mode, detail: detail)
        }
    }

    func checkManually(place: String, minutes: Int, mode: TravelMode) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self, let detail = activeBooking() else { return }

            let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                await publish(minutes: minutes, mode: mode, isManual: true, detail: detail)
                return
            }
            guard let origin = await LaundromatSearchService.locate(trimmed) else {
                if !Task.isCancelled {
                    output?.didFail(message: "Couldn't find \u{201C}\(trimmed)\u{201D}. Try another place, or just enter the travel time.")
                }
                return
            }
            await estimate(from: origin, mode: mode, detail: detail)
        }
    }

    func setReminder(enabled: Bool) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self, let detail = activeBooking(), var plan = store.plan(for: bookingId) else { return }

            if enabled, remindersAllowed {
                var permission = await NotificationService.shared.permission()
                if permission == .notDetermined {
                    permission = await NotificationService.shared.requestPermission() ? .granted : .denied
                }
                plan.reminderOn = permission == .granted ? await schedule(plan, detail: detail) : false
            } else {
                NotificationService.shared.cancel(id: ArrivalPlanStore.notificationId(for: bookingId))
                plan.reminderOn = false
            }
            store.save(plan)
            await publish(plan)
        }
    }

    // MARK: - Work
    private func estimate(from origin: CLLocation, mode: TravelMode, detail: BookingDetail) async {
        guard let laundromat = detail.laundromat else {
            output?.didFail(message: "We don't know where this laundromat is.")
            return
        }
        let destination = CLLocation(latitude: laundromat.latitude, longitude: laundromat.longitude)
        do {
            let minutes = try await TravelTimeService.minutes(from: origin, to: destination, mode: mode)
            if Task.isCancelled { return }
            await publish(minutes: minutes, mode: mode, isManual: false, detail: detail)
        } catch {
            if Task.isCancelled { return }
            output?.didNeedManualInput(message: "Apple Maps couldn't find a route from there. Enter roughly how long it takes instead.")
        }
    }

    private func publish(minutes: Int, mode: TravelMode, isManual: Bool, detail: BookingDetail) async {
        // A new estimate moves the leave time, so any earlier reminder is replaced, never left behind
        var plan = ArrivalPlan(bookingId: bookingId,
                               arriveBy: detail.booking.startTime,
                               travelMinutes: minutes,
                               bufferMinutes: ArrivalCalculator.bufferMinutes,
                               mode: mode,
                               isManualEstimate: isManual,
                               reminderOn: store.plan(for: bookingId)?.reminderOn ?? false)
        if plan.reminderOn {
            plan.reminderOn = await schedule(plan, detail: detail)
        } else {
            NotificationService.shared.cancel(id: ArrivalPlanStore.notificationId(for: bookingId))
        }
        store.save(plan)
        await publish(plan)
    }

    private func publish(_ plan: ArrivalPlan) async {
        output?.didUpdate(ArrivalUpdate(plan: plan,
                                        notificationPermission: await NotificationService.shared.permission(),
                                        remindersAllowed: remindersAllowed))
    }

    private func schedule(_ plan: ArrivalPlan, detail: BookingDetail) async -> Bool {
        guard remindersAllowed, await NotificationService.shared.permission() == .granted else { return false }
        let machine = detail.machine.map { "\($0.type.rawValue.capitalized) \($0.label)" } ?? "your booking"
        let place = detail.laundromat?.name ?? "the laundromat"
        let time = plan.arriveBy.formatted(date: .omitted, time: .shortened)
        return await NotificationService.shared.schedule(
            id: ArrivalPlanStore.notificationId(for: bookingId),
            title: "Time to leave for \(machine)",
            body: "Leave now to reach \(place) by \(time). About \(plan.travelMinutes) min \(plan.mode.phrase).",
            at: plan.leaveAt)
    }

    // MARK: - Helpers
    private func activeBooking() -> BookingDetail? {
        bookings.details.first { $0.booking.id == bookingId && $0.booking.isActiveReservation }
    }

    private func checkInDeadline(for booking: Booking) -> Date {
        booking.holdExpiresAt ?? booking.startTime.addingTimeInterval(TimeInterval(BookingRules.holdMinutes * 60))
    }

    // Switched off in Profile > Notifications
    private var remindersAllowed: Bool {
        NotificationPreferences.shared.isOn(.departureReminders)
    }
}
