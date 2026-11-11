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

    // Same order as the machine cards, so a tapped card maps to the right machine
    private var machines: [Machine] = []
    
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
        machines = data.machines
        view?.showUser(name: data.user.name)
        view?.showLaundromat(name: data.laundromat.name,
                             isOperating: data.laundromat.isOpenNow)
        view?.showMachines(data.machines.map(makeViewModel(from:)))
        view?.showRefreshing(false)
    }
    
    //Conform to HomePresenterProtocol (View → Presenter).
    func viewDidLoad(){
        interactor?.fetchHomeData()
    }

    // Reservations expire and cycles finish while Home is out of sight
    func viewWillAppear() {
        interactor?.fetchHomeData()
    }

    // Any working machine can be reserved now or booked for later; the Reserve sheet shows what is possible
    func didSelectMachine(at index: Int) {
        guard machines.indices.contains(index), machines[index].status != .outOfOrder else { return }
        router?.navigateToReserve(machineId: machines[index].id) { [weak self] in
            self?.interactor?.fetchHomeData()
            self?.router?.showMyLaundry()
        }
    }
    
    //Conform to HomePresenterProtocol (View → Presenter).
    func didTapRefresh(){
        view?.showRefreshing(true)
        interactor?.refreshHomeData()
    }
    
    //Conform to HomePresenterProtocol (View → Presenter).
    func didTapChangeLocation(){
        // Reload so Home shows the laundromat that was just picked
        router?.navigateToLaundromatList { [weak self] in
            self?.interactor?.fetchHomeData()
        }
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
