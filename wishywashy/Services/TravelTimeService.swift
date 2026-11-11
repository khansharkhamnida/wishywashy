//
//  TravelTimeService.swift
//  wishywashy
//

import MapKit

/// Estimated travel time from Apple Maps. It is an estimate, not a promise.
enum TravelTimeService {
    /// Whole minutes, rounded up
    static func minutes(from origin: CLLocation, to destination: CLLocation, mode: TravelMode) async throws -> Int {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: origin, address: nil)
        request.destination = MKMapItem(location: destination, address: nil)
        switch mode {
        case .driving: request.transportType = .automobile
        case .walking: request.transportType = .walking
        case .transit: request.transportType = .transit
        }
        let eta = try await MKDirections(request: request).calculateETA()
        return max(Int(ceil(eta.expectedTravelTime / 60)), 1)
    }
}
