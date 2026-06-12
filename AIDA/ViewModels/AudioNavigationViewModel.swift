import CoreLocation
import Foundation

protocol AudioNavigationViewModelBinding: AnyObject {
    func audioNavigationViewModel(_ viewModel: AudioNavigationViewModel, didUpdateDistanceText text: String)
    func audioNavigationViewModel(_ viewModel: AudioNavigationViewModel, didUpdateAlignment alignment: Double)
    func audioNavigationViewModelDidChangeMode(_ viewModel: AudioNavigationViewModel)
}

final class AudioNavigationViewModel: NSObject {
    enum Mode {
        /// Background color guides toward the target (green = facing it).
        case color
        /// Dark screen; vibration frequency guides toward the target.
        case compass
    }

    weak var binding: AudioNavigationViewModelBinding?

    private(set) var mode: Mode = .color

    var statusText: String { L10n.audioNavigationStatus.current }
    var debugSimulatorLabel: String { L10n.audioNavigationDebugSimulator.current }
    var distancePlaceholder: String { L10n.audioNavigationDistancePlaceholder.current }
    var hintText: String {
        mode == .compass ? L10n.navCompassHint.current : L10n.navColorHint.current
    }
    var modeButtonTitle: String {
        mode == .compass ? L10n.navSwitchToColor.current : L10n.navSwitchToCompass.current
    }

    /// Target is placed 50 m to the user's left once a fix is available.
    private let targetDistanceMeters: Double = 50
    private let arrivalThresholdMeters: Double = 3
    private var targetLocation: CLLocation?

    private let locationManager = CLLocationManager()

    /// Compass mode points the user toward magnetic/true north.
    private let northThresholdDegrees: Double = 8
    private let northResetDegrees: Double = 15

    private var isTrackingRequested = false
    private var isUsingDebugSimulator = false
    private var hasReachedTarget = false
    private var hasReachedNorth = false

    private var lastKnownLocation: CLLocation?
    private var lastKnownHeading: Double?
    private var lastAlignment: Double = 1

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    // MARK: - Mode

    func toggleMode() {
        mode = (mode == .color) ? .compass : .color
        hasReachedNorth = false
        HapticService.shared.stop()
        if mode == .compass, let heading = lastKnownHeading {
            updateCompass(heading: heading)
        }
        binding?.audioNavigationViewModelDidChangeMode(self)
    }

    // MARK: - Tracking

    func startTracking() {
        isTrackingRequested = true
        guard !isUsingDebugSimulator else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        case .denied, .restricted:
            print("[AudioNavigationViewModel] location authorization denied or restricted")
        @unknown default:
            break
        }
    }

    func stopTracking() {
        isTrackingRequested = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        HapticService.shared.stop()
    }

    func setDebugSimulatorEnabled(_ enabled: Bool) {
        isUsingDebugSimulator = enabled
        hasReachedTarget = false
        if enabled {
            locationManager.stopUpdatingLocation()
            locationManager.stopUpdatingHeading()
            HapticService.shared.stop()
        } else if isTrackingRequested {
            startTracking()
        }
    }

    func didUpdateDistance(_ distance: Double) {
        binding?.audioNavigationViewModel(self, didUpdateDistanceText: distanceText(for: distance))

        // Compass mode guides by heading (north), not distance.
        guard mode == .color, !hasReachedTarget else { return }

        if distance <= arrivalThresholdMeters {
            hasReachedTarget = true
            locationManager.stopUpdatingLocation()
            HapticService.shared.triggerSuccess()
            return
        }

        if distance > 50 {
            HapticService.shared.stop()
        } else {
            HapticService.shared.updateGuidance(forDistance: distance)
        }
    }

    // MARK: - Helpers

    private func establishTargetIfNeeded() {
        guard targetLocation == nil, let origin = lastKnownLocation else { return }
        // "Left" is 90° counter-clockwise from where the user faces (north if
        // heading is unknown).
        let leftBearing = (lastKnownHeading ?? 0) - 90
        targetLocation = Self.coordinate(from: origin.coordinate,
                                         distanceMeters: targetDistanceMeters,
                                         bearingDegrees: leftBearing)
    }

    /// Compass mode: drive the vibration from how close the heading is to north.
    /// Facing north = fast pulses; deviating = slower pulses; within a small
    /// threshold = one big "found it" buzz.
    private func updateCompass(heading: Double) {
        let error = min(heading, 360 - heading)   // 0 (north) … 180 (south)
        lastAlignment = error / 180.0
        if error <= northThresholdDegrees {
            if !hasReachedNorth {
                hasReachedNorth = true
                HapticService.shared.triggerSuccess()
            }
        } else if error > northResetDegrees {
            hasReachedNorth = false
            HapticService.shared.updateHeadingGuidance(alignment: lastAlignment)
        } else if !hasReachedNorth {
            HapticService.shared.updateHeadingGuidance(alignment: lastAlignment)
        }
    }

    private func distanceText(for distance: Double) -> String {
        String(format: L10n.audioNavigationDistanceFormat.current, distance)
    }

    /// Color mode: alignment between the heading and the bearing to the target.
    private func recomputeAlignment() {
        guard let target = targetLocation,
              let location = lastKnownLocation,
              let heading = lastKnownHeading else { return }
        let targetBearing = Self.bearing(from: location.coordinate, to: target.coordinate)
        let diff = abs(heading - targetBearing)
        let error = min(diff, 360 - diff)
        let alignment = error / 180.0
        binding?.audioNavigationViewModel(self, didUpdateAlignment: alignment)
    }

    private static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return fmod((atan2(y, x) * 180 / .pi) + 360, 360)
    }

    private static func coordinate(from origin: CLLocationCoordinate2D,
                                   distanceMeters: Double,
                                   bearingDegrees: Double) -> CLLocation {
        let metersPerDegreeLat = 111_320.0
        let bearing = bearingDegrees * .pi / 180
        let deltaLat = (distanceMeters * cos(bearing)) / metersPerDegreeLat
        let metersPerDegreeLon = metersPerDegreeLat * cos(origin.latitude * .pi / 180)
        let deltaLon = (distanceMeters * sin(bearing)) / metersPerDegreeLon
        return CLLocation(latitude: origin.latitude + deltaLat, longitude: origin.longitude + deltaLon)
    }
}

extension AudioNavigationViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastKnownLocation = latest
        establishTargetIfNeeded()
        guard let target = targetLocation else { return }
        didUpdateDistance(latest.distance(from: target))
        recomputeAlignment()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        lastKnownHeading = heading
        switch mode {
        case .color:
            recomputeAlignment()
        case .compass:
            updateCompass(heading: heading)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[AudioNavigationViewModel] location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isTrackingRequested, !isUsingDebugSimulator else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        default:
            break
        }
    }
}
