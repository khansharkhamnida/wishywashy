//
//  Machine.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation

enum MachineType: String, Codable {
    case washer, dryer
}

enum MachineStatus: String, Codable {
    case available, inUse, reserved, outOfOrder
}

struct Machine: Codable, Identifiable {
    let id: String
    let laundromatId: String
    let type: MachineType
    let label: String
    let capacityKg: Int
    var status: MachineStatus
    var pricePerCycle: Decimal
    var cycleMinutes: Int
    var availableAt: Date?
}
