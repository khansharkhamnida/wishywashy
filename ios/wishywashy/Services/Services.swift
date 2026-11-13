//
//  Services.swift
//  wishywashy
//
//  The shared services the screens use. Interactors take them as init parameters
//  with these as the defaults, so tests can pass their own.
//

import Foundation

enum Services {
    static let auth: AuthService = {
        guard AppConfig.current.isLive else { return SampleAuthService() }
        return SupabaseAuthService(config: AppConfig.current.supabase)
    }()

    private static let sampleBookings = LocalBookingService()
    private static var liveBookings: (userId: String, service: BookingService)?

    /// Bookings are still sample data in live mode until a server-backed service exists. Live mode keeps them in a
    /// separate store for each signed-in user, so they never mix with the sample-mode data or with another account.
    static var bookings: BookingService {
        guard AppConfig.current.isLive else { return sampleBookings }
        let userId = Session.user.id
        if let liveBookings, liveBookings.userId == userId { return liveBookings.service }
        let defaults = UserDefaults(suiteName: "wishywashy.live.\(userId)") ?? .standard
        let service = LocalBookingService(store: LocalStore(defaults: defaults))
        liveBookings = (userId, service)
        return service
    }
}
