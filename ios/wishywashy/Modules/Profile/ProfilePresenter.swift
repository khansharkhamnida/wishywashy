//
//  ProfilePresenter.swift
//  wishywashy
//

import Foundation

final class ProfilePresenter: ProfilePresenterProtocol, ProfileInteractorOutputProtocol {
    weak var view: ProfileViewProtocol?
    var interactor: ProfileInteractorInputProtocol?
    var router: ProfileRouterProtocol?

    func viewDidLoad() { interactor?.fetchProfile() }
    func viewWillAppear() { interactor?.fetchProfile() }

    func didSelectMenuItem(_ item: ProfileMenuItem) {
        router?.navigate(to: item)
    }

    func didConfirmSignOut() {
        interactor?.signOut()
    }

    // ProfileInteractorOutputProtocol
    func didFetchProfile(_ data: ProfileData) {
        view?.showProfile(ProfileViewModel(
            initial: String(data.user.name.prefix(1)).uppercased(),
            name: data.user.name,
            email: data.user.email,
            stats: [
                ProfileStatViewModel(value: "\(data.totalBookings)", title: "Bookings", tone: .pink),
                ProfileStatViewModel(value: "\(data.completedBookings)", title: "Completed", tone: .mint),
                ProfileStatViewModel(value: Money.string(data.totalSpent), title: "Spent", tone: .lilac)
            ],
            canSignOut: interactor?.canSignOut ?? false))
    }
}
