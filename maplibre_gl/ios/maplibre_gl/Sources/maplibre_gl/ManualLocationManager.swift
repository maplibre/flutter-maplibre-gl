import CoreLocation
import MapLibre

/// A custom ``MLNLocationManager`` that feeds app-provided locations into the
/// map's user-location component instead of using Core Location.
///
/// Assigned to `mapView.locationManager` when the map is created with
/// `locationSource: ManualLocationSource()`. The app pushes updates via
/// ``push(_:)`` (driven from the `locationComponent#setManualLocation` method
/// channel call); the map view's delegate then fires `map#onUserLocationUpdated`
/// automatically.
class ManualLocationManager: NSObject, MLNLocationManager {
    weak var delegate: MLNLocationManagerDelegate?

    // The app supplies locations directly, so report full authorization and
    // treat permission requests / start-stop as no-ops.
    var authorizationStatus: CLAuthorizationStatus {
        return .authorizedAlways
    }

    var headingOrientation: CLDeviceOrientation = .portrait

    func requestAlwaysAuthorization() {}

    func requestWhenInUseAuthorization() {}

    func startUpdatingLocation() {}

    func stopUpdatingLocation() {}

    func startUpdatingHeading() {}

    func stopUpdatingHeading() {}

    func dismissHeadingCalibrationDisplay() {}

    /// Pushes an app-provided location into the map's user-location component.
    func push(_ location: CLLocation) {
        delegate?.locationManager(self, didUpdate: [location])
    }
}
