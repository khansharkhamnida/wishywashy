//
//  ArrivalCheckRouter.swift
//  wishywashy
//

import UIKit

final class ArrivalCheckRouter: ArrivalCheckRouterProtocol {
    weak var viewController: UIViewController?

    static func createModule(bookingId: String) -> UIViewController {
        let view = ArrivalCheckViewController()
        let presenter = ArrivalCheckPresenter()
        let interactor = ArrivalCheckInteractor(bookingId: bookingId)
        let router = ArrivalCheckRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view

        return view
    }

    /// Shows the check as a sheet on top of `presenter`
    static func present(bookingId: String, from presenter: UIViewController?) {
        let check = createModule(bookingId: bookingId)
        if let sheet = check.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        presenter?.present(check, animated: true)
    }

    func close() {
        viewController?.dismiss(animated: true)
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
