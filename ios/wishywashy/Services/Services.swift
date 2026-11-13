//
//  Services.swift
//  wishywashy
//
//  The shared services the screens use. Interactors take them as init parameters
//  with these as the defaults, so tests can pass their own.
//

import Foundation

enum Services {
    static let bookings: BookingService = LocalBookingService()
}
