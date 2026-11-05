//
//  HomeProtocols.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//
import UIKit

//Presenter -> View
protocol HomeViewProtocol: AnyObject {
    func showUser(name: String)
    func showLaundromat(name: String, isOperating: Bool)
    func showMachines(_ machines: [MachineCardViewModel])
}

//View -> Presenter
protocol HomePresenterProtocol: AnyObject {
    func viewDidLoad()
    func didTapRefresh()
    func didTapChangeLocation()
}

//Presenter -> Interactor
protocol HomeInteractorInputProtocol: AnyObject {
    func fetchHomeData()
}

//Interactor -> Presenter
protocol HomeInteractorOutputProtocol: AnyObject {
    func didFetchHomeData(_ data: HomeData)
}
protocol HomeRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToLaundromatList()
}
