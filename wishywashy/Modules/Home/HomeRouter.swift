//
//  HomeRouter.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 4/11/26.
//

import UIKit

final class HomeRouter: HomeRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule() -> UIViewController {
        let view = HomeViewController()
        let presenter = HomePresenter()
        let interactor = HomeInteractor()
        let router = HomeRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view

        return view
    }

    func navigateToLaundromatList() {
        //let vc = LaundromatListRouter.createModule()
        //viewController?.navigationController?.pushViewController(vc, animated: true)
    }
}
