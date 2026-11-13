//
//  ProfileRouter.swift
//  wishywashy
//

import UIKit

final class ProfileRouter: ProfileRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule() -> UIViewController {
        let view = ProfileViewController()
        let presenter = ProfilePresenter()
        let interactor = ProfileInteractor()
        let router = ProfileRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view

        return view
    }

    func navigate(to item: ProfileMenuItem) {
        let page: UIViewController
        switch item {
        case .paymentMethods: page = PaymentMethodsViewController()
        case .savedLaundromats: page = SavedLaundromatsViewController()
        case .notifications: page = NotificationSettingsViewController()
        case .help: page = HelpSupportViewController()
        }
        page.hidesBottomBarWhenPushed = true
        viewController?.navigationController?.pushViewController(page, animated: true)
    }
}
