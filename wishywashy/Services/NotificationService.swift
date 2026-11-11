//
//  NotificationService.swift
//  wishywashy
//

import UserNotifications

enum PermissionState {
    case notDetermined, granted, denied
}

/// Local notifications only; nothing here talks to a server.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    func permission() async -> PermissionState {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral: return .granted
        default: return .denied
        }
    }

    /// Shows the system prompt the first time; returns whether notifications are allowed
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Schedules one notification. Using the same id again replaces the earlier one.
    func schedule(id: String, title: String, body: String, at date: Date) async -> Bool {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return false }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    // Without this, a notification that arrives while the app is open would be silent
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
