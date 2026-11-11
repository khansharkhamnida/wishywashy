//
//  ReserveRouter.swift
//  wishywashy
//

import UIKit

final class ReserveRouter: ReserveRouterProtocol {
    weak var viewController: UIViewController?
    private var onReserved: (() -> Void)?

    /// onReserved runs once the reservation has gone through and the sheet has closed
    static func createModule(machineId: String, onReserved: (() -> Void)?) -> UIViewController {
        let view = ReserveViewController()
        let presenter = ReservePresenter()
        let interactor = ReserveInteractor(machineId: machineId)
        let router = ReserveRouter()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.output = presenter
        router.viewController = view
        router.onReserved = onReserved

        return view
    }

    func close() {
        viewController?.dismiss(animated: true)
    }

    func closeAfterReserving() {
        let onReserved = onReserved
        viewController?.dismiss(animated: true) { onReserved?() }
    }
}
