//
//  LaundromatSearchService.swift
//  wishywashy
//

import MapKit

/// Finds real laundromats with Apple Maps. Results only have a name, address and location,
/// so they carry no machine, rating or opening-hours data.
enum LaundromatSearchService {

    /// Turns text such as "Tampines" or "520123" into a coordinate, or nil if nothing matches.
    static func locate(_ query: String) async -> CLLocation? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        return response.mapItems.first?.location
    }

    static func laundromats(around center: CLLocation, radius: CLLocationDistance = 5_000) async throws -> [Laundromat] {
        var items = try await search("laundromat", around: center, radius: radius)
        if items.isEmpty {
            items = try await search("laundry", around: center, radius: radius)
        }
        return items
    }

    private static func search(_ text: String, around center: CLLocation, radius: CLLocationDistance) async throws -> [Laundromat] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(center: center.coordinate,
                                            latitudinalMeters: radius * 2,
                                            longitudinalMeters: radius * 2)
        request.resultTypes = .pointOfInterest
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.map { makeLaundromat(from: $0, center: center) }
    }

    private static func makeLaundromat(from item: MKMapItem, center: CLLocation) -> Laundromat {
        let location = item.location
        let name = item.name ?? "Laundromat"
        let latitude = Int((location.coordinate.latitude * 100_000).rounded())
        let longitude = Int((location.coordinate.longitude * 100_000).rounded())
        return Laundromat(id: "map:\(name)|\(latitude)|\(longitude)",
                          name: name,
                          address: item.address?.fullAddress ?? "Address not available",
                          latitude: location.coordinate.latitude,
                          longitude: location.coordinate.longitude,
                          distanceMeters: location.distance(from: center),
                          isOpenNow: nil,
                          rating: nil)
    }
}
