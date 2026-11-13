//
//  BookingsRouter.swift
//  wishywashy
//

import UIKit

final class BookingsRouter: BookingsRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule() -> UIViewController {
        let view = BookingsViewController()
        let presenter = BookingsPresenter()
        let interactor = BookingsInteractor()
        let router = BookingsRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view

        return view
    }

    func navigateToArrivalCheck(bookingId: String) {
        ArrivalCheckRouter.present(bookingId: bookingId, from: viewController)
    }
}
