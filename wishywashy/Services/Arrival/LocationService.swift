//
//  LocationService.swift
//  wishywashy
//

import CoreLocation

/// One-shot access to the user's current location, asking for permission when needed.
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<CLLocation?, Never>] = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var permission: PermissionState {
        switch manager.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        default: return .denied
        }
    }

    /// Returns nil when permission is denied or no location can be found.
    func currentLocation() async -> CLLocation? {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            return nil
        }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            // Only the first caller starts a request; the rest share its result
            guard waiting.count == 1 else { return }
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finish(with location: CLLocation?) {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(returning: location) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if !self.waiting.isEmpty { manager.requestLocation() }
            case .denied, .restricted:
                self.finish(with: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in self.finish(with: latest) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(with: nil) }
    }
}
