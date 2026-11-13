//
//  ArrivalPlanStore.swift
//  wishywashy
//

import Foundation

/// The leave-by plan for each booking, kept on the device.
/// Removing a plan also cancels its notification, so a cancelled or changed booking never reminds.
final class ArrivalPlanStore {
    static let shared = ArrivalPlanStore()

    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    var plans: [String: ArrivalPlan] {
        store.load([String: ArrivalPlan].self, key: StoreKey.arrivalPlans) ?? [:]
    }

    func plan(for bookingId: String) -> ArrivalPlan? {
        plans[bookingId]
    }

    func save(_ plan: ArrivalPlan) {
        var current = plans
        current[plan.bookingId] = plan
        store.save(current, key: StoreKey.arrivalPlans)
    }

    func remove(bookingId: String) {
        var current = plans
        guard current.removeValue(forKey: bookingId) != nil else { return }
        store.save(current, key: StoreKey.arrivalPlans)
        NotificationService.shared.cancel(id: Self.notificationId(for: bookingId))
    }

    /// Removes every plan, and its reminder, whose booking is not in `bookingIds`
    func prune(keeping bookingIds: Set<String>) {
        for id in plans.keys where !bookingIds.contains(id) {
            remove(bookingId: id)
        }
    }

    static func notificationId(for bookingId: String) -> String {
        "leave-\(bookingId)"
    }
}
