//
//  ProfileProtocols.swift
//  wishywashy
//

import UIKit

enum ProfileMenuItem {
    case paymentMethods, savedLaundromats, notifications, help
}

struct ProfileStatViewModel {
    let value: String
    let title: String
    let tone: Theme.Tone
}

struct ProfileViewModel {
    let initial: String
    let name: String
    let email: String
    let stats: [ProfileStatViewModel]
    /// Only live mode has accounts, so sample mode shows no sign-out row
    let canSignOut: Bool
}

// Presenter -> View
protocol ProfileViewProtocol: AnyObject {
    func showProfile(_ model: ProfileViewModel)
}

// View -> Presenter
protocol ProfilePresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func didSelectMenuItem(_ item: ProfileMenuItem)
    func didConfirmSignOut()
}

// Presenter -> Interactor
protocol ProfileInteractorInputProtocol: AnyObject {
    func fetchProfile()
    var canSignOut: Bool { get }
    func signOut()
}

// Interactor -> Presenter
protocol ProfileInteractorOutputProtocol: AnyObject {
    func didFetchProfile(_ data: ProfileData)
}

// Presenter -> Router
protocol ProfileRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigate(to item: ProfileMenuItem)
}
