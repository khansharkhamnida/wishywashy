//
//  AuthRouter.swift
//  wishywashy
//

import UIKit

/// Builds the signed-out flow: Login, with Register pushed on top. Signing in changes the auth state,
/// and `SceneDelegate` then replaces this flow with the tab bar.
enum AuthRouter {
    static func createModule() -> UIViewController {
        let navigation = UINavigationController(rootViewController: LoginRouter.createModule())
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.view.backgroundColor = Theme.background
        return navigation
    }
}

final class LoginRouter: LoginRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule() -> UIViewController {
        let view = LoginViewController()
        let presenter = LoginPresenter()
        let interactor = LoginInteractor()
        let router = LoginRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view

        return view
    }

    func showRegister() {
        viewController?.navigationController?.pushViewController(RegisterRouter.createModule(), animated: true)
    }
}

final class RegisterRouter: RegisterRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule() -> UIViewController {
        let view = RegisterViewController()
        let presenter = RegisterPresenter()
        let interactor = RegisterInteractor()
        let router = RegisterRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view

        return view
    }

    func showLogin() {
        viewController?.navigationController?.popViewController(animated: true)
    }
}
