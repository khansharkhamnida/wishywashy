//
//  HomeInteractor.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//
import Foundation

class HomeInteractor: HomeInteractorInputProtocol {
    weak var output: HomeInteractorOutputProtocol?   // weak = avoids a retain cycle

    func fetchHomeData(){
        let data = HomeData(user: MockUser.current, laundromat: MockLaundromat.selected, machines: MockMachines.all)
        output?.didFetchHomeData(data)
    }
    
    // TODO: filter machines by selected laundromat
    // TODO: sort available machines first
    // TODO: handle failure
}
