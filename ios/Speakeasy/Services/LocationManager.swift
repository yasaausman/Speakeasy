import Foundation
import CoreLocation

/// A coarse, one-shot location source for "near me" business lookups. Reverse-
/// geocodes to a city + region string (e.g. "Austin, TX") — never coordinates —
/// which is all the backend needs and keeps precise location off the wire.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    /// "City, ST" once known; nil until permission is granted and a fix arrives.
    @Published var placemark: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // coarse is plenty
    }

    /// Ask for permission (once) and grab a single coarse fix. Safe to call repeatedly.
    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break // denied/restricted → leave placemark nil; backend handles it
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            guard let p = placemarks?.first else { return }
            let city = p.locality ?? p.subAdministrativeArea
            let region = p.administrativeArea
            let label = [city, region].compactMap { $0 }.joined(separator: ", ")
            if !label.isEmpty { placemark = label }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Leave placemark nil — a lookup without a location still works, just less targeted.
    }
}
