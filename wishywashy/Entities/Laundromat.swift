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
    /// True when machines and bookings are managed in this app, false for listings from Apple Maps
    var isPartner = false
}

enum SortingCriteria: CaseIterable {
    case distance
    case rating
    case name
    case price
    case open
}


struct LaundromatListViewModel {
    let name: String
    let address: String
    let distance: String
    let rating: String
    let status: String
    let tone: Theme.Tone
    let isSelected: Bool
    let isSaved: Bool
    let showsMachines: Bool
    let washersFree: Int
    let dryersFree: Int
}

