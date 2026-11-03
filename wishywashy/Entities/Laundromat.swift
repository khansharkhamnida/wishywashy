//
//  Laundromat.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation

struct Laundromat: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var distanceMeters: Double?
    var isOpenNow: Bool?
    var rating: Double?
    var machines: [Machine] = []
}
