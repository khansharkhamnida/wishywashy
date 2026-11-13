//
//  ProfileInteractor.swift
//  wishywashy
//

import Foundation

final class ProfileInteractor: ProfileInteractorInputProtocol {
    weak var output: ProfileInteractorOutputProtocol?

    private let bookings: BookingService
    private let auth: AuthService

    init(bookings: BookingService = Services.bookings, auth: AuthService = Services.auth) {
        self.bookings = bookings
        self.auth = auth
    }

    var canSignOut: Bool { auth.requiresSignIn }

    /// Signing out changes the auth state, and `SceneDelegate` then swaps the tab bar for the login screen
    func signOut() {
        Task { await auth.signOut() }
    }

    func fetchProfile() {
        let user = Session.user
        let bookings = bookings.bookings.filter { $0.userId == user.id }
        let completed = bookings.filter { $0.status == .completed }
        output?.didFetchProfile(ProfileData(user: user,
                                            totalBookings: bookings.count,
                                            completedBookings: completed.count,
                                            totalSpent: completed.reduce(Decimal(0)) { $0 + $1.totalPrice }))
    }
}
