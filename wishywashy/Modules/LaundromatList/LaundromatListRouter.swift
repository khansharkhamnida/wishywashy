//
//  LaundromatListRouter.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation
import UIKit

final class LaundromatListRouter: LaundromatListRouterProtocol {
    
    weak var viewController: UIViewController?
    private var onSelect: (() -> Void)?

    static func createModule() -> UIViewController {
        createModule(onSelect: nil)
    }

    // onSelect lets the screen that opened the list react when a laundromat is picked
    static func createModule(onSelect: (() -> Void)?) -> UIViewController {
        
        let view = LaundromatListViewController()
        let presenter = LaundromatListPresenter()
        let interactor = LaundromatListInteractor()
        let router = LaundromatListRouter()
        
        view.presenter = presenter
        
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        
        interactor.output = presenter
        router.viewController = view
        router.onSelect = onSelect

        return view
        
    }

    func close() {
        onSelect?()
        guard let nav = viewController?.navigationController else { return }
        if nav.viewControllers.first === viewController {
            nav.dismiss(animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }
}
