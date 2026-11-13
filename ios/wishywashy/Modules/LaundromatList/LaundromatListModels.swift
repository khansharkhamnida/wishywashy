//
//  LaundromatListModels.swift
//  wishywashy
//

import Foundation

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
