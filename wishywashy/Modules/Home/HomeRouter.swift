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

    func navigateToLaundromatList(onSelect: @escaping () -> Void) {
        let list = LaundromatListRouter.createModule(onSelect: onSelect)
        let nav = UINavigationController(rootViewController: list)
        viewController?.present(nav, animated: true, completion: nil)
    }

    private static let myLaundryTabIndex = 2

    func navigateToReserve(machineId: String, onReserved: @escaping () -> Void) {
        let reserve = ReserveRouter.createModule(machineId: machineId, onReserved: onReserved)
        if let sheet = reserve.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        viewController?.present(reserve, animated: true)
    }

    func showMyLaundry() {
        viewController?.tabBarController?.selectedIndex = Self.myLaundryTabIndex
    }
}
