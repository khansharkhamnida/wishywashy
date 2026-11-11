//
//  HomeData.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

struct HomeData {
    let user: User
    let laundromat: Laundromat
    let machines: [Machine]
}

// What one machine cell displays. Later the Presenter will build these from Machine entities.
struct MachineCardViewModel {
    let name: String
    let isAvailable: Bool
    let subtitle: String
    let priceText: String?
    let detailText: String?
}
