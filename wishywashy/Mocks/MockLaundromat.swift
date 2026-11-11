//
//  MockLaundromat.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation

enum MockLaundromat {
    // id matches the laundromatId used in MockMachines
    private static let tampines = Laundromat(id: "l1",
                                     name: "WishyWash Tampines",
                                     address: "Blk 4 Tampines Street 11, Singapore",
                                     latitude: 1.3496,
                                     longitude: 103.9568,
                                     distanceMeters: 850,
                                     isOpenNow: true,
                                     rating: 4.5,
                                     isPartner: true)

    static let all: [Laundromat] = [
        tampines,
        // Closed
        Laundromat(id: "l2",
                   name: "WishyWash Orchard",
                   address: "Somerset Road, Orchard, Singapore",
                   latitude: 1.3048,
                   longitude: 103.8318,
                   distanceMeters: 2300,
                   isOpenNow: false,
                   rating: 4.2,
                   isPartner: true),
        // Far away and no rating yet
        Laundromat(id: "l3",
                   name: "WishyWash Jurong East",
                   address: "Jurong Gateway Road, Jurong East, Singapore",
                   latitude: 1.3329,
                   longitude: 103.7436,
                   distanceMeters: 7800,
                   isOpenNow: true,
                   rating: nil,
                   isPartner: true),
        // Unknown open status and unknown distance
        Laundromat(id: "l4",
                   name: "WishyWash Bugis",
                   address: "Victoria Street, Bugis, Singapore",
                   latitude: 1.3009,
                   longitude: 103.8559,
                   distanceMeters: nil,
                   isOpenNow: nil,
                   rating: 3.8,
                   isPartner: true)
    ]
}
