//
//  mockMachine.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import Foundation

enum MockMachines {
    /// Always read through `all`, which first moves reservations and cycles forward in time
    static var all: [Machine] {
        MockBooking.advance()
        return stored
    }

    /// Raw storage, for MockBooking only
    static var stored: [Machine] = MockStore.load([Machine].self, key: MockStore.machinesKey) ?? samples

    /// Set when a machine changes, so MockBooking knows to save
    static var isDirty = false

    private static let samples: [Machine] = [
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
        Machine(id: "d02", laundromatId: "l1", type: .dryer, label: "D02",
                capacityKg: 18, status: .available, pricePerCycle: 4,
                cycleMinutes: 40, availableAt: nil),
        // Out of order
        Machine(id: "w05", laundromatId: "l1", type: .washer, label: "W05",
                capacityKg: 10, status: .outOfOrder, pricePerCycle: 5,
                cycleMinutes: 30, availableAt: nil),
        // In use but no finish time, to test the optional
        Machine(id: "w06", laundromatId: "l1", type: .washer, label: "W06",
                capacityKg: 15, status: .inUse, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: nil),
        // In use by booking b2, which has 8 minutes left
        Machine(id: "d03", laundromatId: "l1", type: .dryer, label: "D03",
                capacityKg: 18, status: .inUse, pricePerCycle: 4,
                cycleMinutes: 40, availableAt: Date().addingTimeInterval(8 * 60)),
        // Orchard: pricier, mostly busy
        Machine(id: "w01-l2", laundromatId: "l2", type: .washer, label: "W01",
                capacityKg: 15, status: .inUse, pricePerCycle: 8,
                cycleMinutes: 36, availableAt: Date().addingTimeInterval(10 * 60)),
        Machine(id: "w02-l2", laundromatId: "l2", type: .washer, label: "W02",
                capacityKg: 15, status: .inUse, pricePerCycle: 8,
                cycleMinutes: 36, availableAt: Date().addingTimeInterval(12 * 60)),
        Machine(id: "w03-l2", laundromatId: "l2", type: .washer, label: "W03",
                capacityKg: 10, status: .inUse, pricePerCycle: 6,
                cycleMinutes: 30, availableAt: Date().addingTimeInterval(12 * 60)),
        Machine(id: "w04-l2", laundromatId: "l2", type: .washer, label: "W04",
                capacityKg: 10, status: .inUse, pricePerCycle: 6,
                cycleMinutes: 30, availableAt: Date().addingTimeInterval(25 * 60)),
        Machine(id: "w05-l2", laundromatId: "l2", type: .washer, label: "W05",
                capacityKg: 15, status: .available, pricePerCycle: 8,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w06-l2", laundromatId: "l2", type: .washer, label: "W06",
                capacityKg: 10, status: .outOfOrder, pricePerCycle: 6,
                cycleMinutes: 30, availableAt: nil),
        Machine(id: "d01-l2", laundromatId: "l2", type: .dryer, label: "D01",
                capacityKg: 18, status: .inUse, pricePerCycle: 5,
                cycleMinutes: 40, availableAt: Date().addingTimeInterval(16 * 60)),
        Machine(id: "d02-l2", laundromatId: "l2", type: .dryer, label: "D02",
                capacityKg: 18, status: .inUse, pricePerCycle: 5,
                cycleMinutes: 40, availableAt: Date().addingTimeInterval(8 * 60)),
        Machine(id: "d03-l2", laundromatId: "l2", type: .dryer, label: "D03",
                capacityKg: 18, status: .available, pricePerCycle: 5,
                cycleMinutes: 40, availableAt: nil),
        Machine(id: "d04-l2", laundromatId: "l2", type: .dryer, label: "D04",
                capacityKg: 18, status: .inUse, pricePerCycle: 5,
                cycleMinutes: 40, availableAt: nil),
        // Jurong East: cheapest
        Machine(id: "w01-l3", laundromatId: "l3", type: .washer, label: "W01",
                capacityKg: 15, status: .available, pricePerCycle: 4,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w02-l3", laundromatId: "l3", type: .washer, label: "W02",
                capacityKg: 15, status: .available, pricePerCycle: 4,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w03-l3", laundromatId: "l3", type: .washer, label: "W03",
                capacityKg: 10, status: .available, pricePerCycle: 3,
                cycleMinutes: 30, availableAt: nil),
        Machine(id: "w04-l3", laundromatId: "l3", type: .washer, label: "W04",
                capacityKg: 10, status: .available, pricePerCycle: 3,
                cycleMinutes: 30, availableAt: nil),
        Machine(id: "w05-l3", laundromatId: "l3", type: .washer, label: "W05",
                capacityKg: 15, status: .available, pricePerCycle: 4,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w06-l3", laundromatId: "l3", type: .washer, label: "W06",
                capacityKg: 10, status: .outOfOrder, pricePerCycle: 3,
                cycleMinutes: 30, availableAt: nil),
        Machine(id: "d01-l3", laundromatId: "l3", type: .dryer, label: "D01",
                capacityKg: 18, status: .available, pricePerCycle: 2,
                cycleMinutes: 40, availableAt: nil),
        Machine(id: "d02-l3", laundromatId: "l3", type: .dryer, label: "D02",
                capacityKg: 18, status: .available, pricePerCycle: 2,
                cycleMinutes: 40, availableAt: nil),
        Machine(id: "d03-l3", laundromatId: "l3", type: .dryer, label: "D03",
                capacityKg: 18, status: .available, pricePerCycle: 2,
                cycleMinutes: 40, availableAt: nil),
        Machine(id: "d04-l3", laundromatId: "l3", type: .dryer, label: "D04",
                capacityKg: 18, status: .inUse, pricePerCycle: 2,
                cycleMinutes: 40, availableAt: nil),
        // Bugis: mid price
        Machine(id: "w01-l4", laundromatId: "l4", type: .washer, label: "W01",
                capacityKg: 15, status: .available, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w02-l4", laundromatId: "l4", type: .washer, label: "W02",
                capacityKg: 15, status: .inUse, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: Date().addingTimeInterval(12 * 60)),
        Machine(id: "w03-l4", laundromatId: "l4", type: .washer, label: "W03",
                capacityKg: 10, status: .available, pricePerCycle: 5,
                cycleMinutes: 30, availableAt: nil),
        Machine(id: "w04-l4", laundromatId: "l4", type: .washer, label: "W04",
                capacityKg: 10, status: .inUse, pricePerCycle: 5,
                cycleMinutes: 30, availableAt: Date().addingTimeInterval(25 * 60)),
        Machine(id: "w05-l4", laundromatId: "l4", type: .washer, label: "W05",
                capacityKg: 15, status: .available, pricePerCycle: 6,
                cycleMinutes: 36, availableAt: nil),
        Machine(id: "w06-l4", laundromatId: "l4", type: .washer, label: "W06",
                capacityKg: 10, status: .outOfOrder, pricePerCycle: 5,
                cycleMinutes: 30, availableAt: nil),
        Machine(id: "d01-l4", laundromatId: "l4", type: .dryer, label: "D01",
                capacityKg: 18, status: .available, pricePerCycle: 3,
                cycleMinutes: 40, availableAt: nil),
        Machine(id: "d02-l4", laundromatId: "l4", type: .dryer, label: "D02",
                capacityKg: 18, status: .inUse, pricePerCycle: 3,
                cycleMinutes: 40, availableAt: Date().addingTimeInterval(8 * 60)),
        Machine(id: "d03-l4", laundromatId: "l4", type: .dryer, label: "D03",
                capacityKg: 18, status: .available, pricePerCycle: 3,
                cycleMinutes: 40, availableAt: nil),
        Machine(id: "d04-l4", laundromatId: "l4", type: .dryer, label: "D04",
                capacityKg: 18, status: .inUse, pricePerCycle: 3,
                cycleMinutes: 40, availableAt: nil)
    ]

    static func update(_ id: String, _ change: (inout Machine) -> Void) {
        guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
        change(&stored[index])
        isDirty = true
    }

}
