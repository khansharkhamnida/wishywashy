//
//  mockMachine.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation

enum MockMachines {
    static let all: [Machine] = [
        Machine(id: "w01", laundromatId: "l1", type: .washer, label: "W01",
                capacityKg: 15, status: .available, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w02", laundromatId: "l1", type: .washer, label: "W02",
                capacityKg: 15, status: .inUse, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: Date().addingTimeInterval(18 * 60)),
        Machine(id: "w03", laundromatId: "l1", type: .washer, label: "W03",
                capacityKg: 15, status: .available, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w04", laundromatId: "l1", type: .washer, label: "W04",
                capacityKg: 10, status: .inUse, pricePerCycle: 5,
                cycleMinutes: 30, availableAt: Date().addingTimeInterval(5 * 60)),
        // Dryer
        Machine(id: "d01", laundromatId: "l1", type: .dryer, label: "D01",
                capacityKg: 18, status: .available, pricePerCycle: 4,
                cycleMinutes: 40, availableAt: nil),
        // Reserved
        Machine(id: "d02", laundromatId: "l1", type: .dryer, label: "D02",
                capacityKg: 18, status: .reserved, pricePerCycle: 4,
                cycleMinutes: 40, availableAt: nil),
        // Out of order
        Machine(id: "w05", laundromatId: "l1", type: .washer, label: "W05",
                capacityKg: 10, status: .outOfOrder, pricePerCycle: 5,
                cycleMinutes: 30, availableAt: nil),
        // In use but no finish time, to test the optional
        Machine(id: "w06", laundromatId: "l1", type: .washer, label: "W06",
                capacityKg: 15, status: .inUse, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: nil),
        // In use with a finish time in the past, to test "Finishing soon"
        Machine(id: "d03", laundromatId: "l1", type: .dryer, label: "D03",
                capacityKg: 18, status: .inUse, pricePerCycle: 4,
                cycleMinutes: 40, availableAt: Date().addingTimeInterval(-60))
    ]
}
