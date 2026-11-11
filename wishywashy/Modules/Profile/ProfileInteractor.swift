//
//  ProfileInteractor.swift
//  wishywashy
//

import Foundation

final class ProfileInteractor: ProfileInteractorInputProtocol {
    weak var output: ProfileInteractorOutputProtocol?

    func fetchProfile() {
        let user = MockUser.current
        let bookings = MockBooking.all.filter { $0.userId == user.id }
        let completed = bookings.filter { $0.status == .completed }
        output?.didFetchProfile(ProfileData(user: user,
                                            totalBookings: bookings.count,
                                            completedBookings: completed.count,
                                            totalSpent: completed.reduce(Decimal(0)) { $0 + $1.totalPrice }))
    }
}
