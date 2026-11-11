//
//  MyLaundryRouter.swift
//  wishywashy
//

import UIKit

final class MyLaundryRouter: MyLaundryRouterProtocol {
    weak var viewController: UIViewController?

    private static let bookingsTabIndex = 1

    static func createModule() -> UIViewController {
        let view = MyLaundryViewController()
        let presenter = MyLaundryPresenter()
        let interactor = MyLaundryInteractor()
        let router = MyLaundryRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view

        return view
    }

    func navigateToGames() {
        let games = GamesViewController()
        games.hidesBottomBarWhenPushed = true
        viewController?.navigationController?.pushViewController(games, animated: true)
    }

    func collectPayment(_ request: PaymentRequest) async -> PaymentOutcome {
        guard let viewController else { return .cancelled }
        return await PaymentServices.current.pay(request, from: viewController)
    }

    func navigateToArrivalCheck(bookingId: String) {
        ArrivalCheckRouter.present(bookingId: bookingId, from: viewController)
    }

    func navigateToBookings() {
        viewController?.tabBarController?.selectedIndex = Self.bookingsTabIndex
    }
}
