//
//  HomePresenter.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 4/11/26.
//

import Foundation
import UIKit

class HomePresenter: HomePresenterProtocol, HomeInteractorOutputProtocol {
    
    
    weak var view: HomeViewProtocol?
    var interactor: HomeInteractorInputProtocol?
    var router: HomeRouterProtocol?
    
    private let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
    
    // Conform to HomeInteractorOutputProtocol (Interactor → Presenter)
    func didFetchHomeData(_ data: HomeData) {
        view?.showUser(name: data.user.name)
        view?.showLaundromat(name: data.laundromat.name,
                             isOperating: data.laundromat.isOpenNow ?? false)
        view?.showMachines(data.machines.map(makeViewModel(from:)))
    }
    
    //Conform to HomePresenterProtocol (View → Presenter).
    func viewDidLoad(){
        interactor?.fetchHomeData()
    }
    
    //Conform to HomePresenterProtocol (View → Presenter).
    func didTapRefresh(){
        interactor?.fetchHomeData()
    }
    
    //Conform to HomePresenterProtocol (View → Presenter).
    func didTapChangeLocation(){
        router?.navigateToLaundromatList()
    }

    func makeViewModel(from machine: Machine) -> MachineCardViewModel {
        let detailText: String?
        var priceText: String? = nil

        switch machine.status {
        case .available:
            detailText = "\(machine.cycleMinutes) min cycle"
        case .inUse:
            if let availableAt = machine.availableAt {
                let minutesLeft = Int(ceil(availableAt.timeIntervalSinceNow / 60))
                detailText = minutesLeft <= 0
                    ? "Finishing soon"
                    : "Available in \(minutesLeft) min (\(timeFormatter.string(from: availableAt)))"
            } else {
                detailText = "In use"
            }
        case .reserved:
            detailText = "Reserved"
        case .outOfOrder:
            detailText = "Out of order"
        }

        if machine.status != .outOfOrder,
           let price = priceFormatter.string(from: NSDecimalNumber(decimal: machine.pricePerCycle)) {
            priceText = "S$\(price)"
        }

        return MachineCardViewModel(
            name: machine.label,
            isAvailable: machine.status == .available,
            subtitle: "\(machine.type.rawValue.capitalized) · \(machine.capacityKg) kg",
            priceText: priceText,
            detailText: detailText
        )
    }
    
    
}
