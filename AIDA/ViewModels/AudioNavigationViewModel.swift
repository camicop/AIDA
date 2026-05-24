import CoreLocation
import Foundation

protocol AudioNavigationViewModelBinding: AnyObject {
    func audioNavigationViewModel(_ viewModel: AudioNavigationViewModel, didUpdateDistanceText text: String)
    func audioNavigationViewModel(_ viewModel: AudioNavigationViewModel, didUpdateAlignment alignment: Double)
}

final class AudioNavigationViewModel: NSObject {
    weak var binding: AudioNavigationViewModelBinding?

    var statusText: String { L10n.audioNavigationStatus.current }
    var debugSimulatorLabel: String { L10n.audioNavigationDebugSimulator.current }
    var distancePlaceholder: String { L10n.audioNavigationDistancePlaceholder.current }

    private let targetLocation = CLLocation(latitude: 46.047556, longitude: 11.134361)
    private let sampleSpeech: String
    private let targetReachedSpeech: String

    private let speechService = SpeechService()
    private let locationManager = CLLocationManager()

    private var isTrackingRequested = false
    private var isUsingDebugSimulator = false
    private var hasReachedTarget = false

    private var lastKnownLocation: CLLocation?
    private var lastKnownHeading: Double?

    override init() {
        self.sampleSpeech = L10n.audioNavigationSampleSpeech.current
        self.targetReachedSpeech = L10n.audioNavigationTargetReached.current
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    func startNarration() {
        speechService.speak(sampleSpeech)
    }

    func stopNarration() {
        speechService.stop()
    }

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

        if distance > 50.0 {
            print("[AudioNavigationViewModel] Too far: \(String(format: "%.1f", distance)) m")
            HapticService.shared.stop()
            return
        }

        if distance > 3.0 {
            HapticService.shared.updateGuidance(forDistance: distance)
            return
        }

        guard !hasReachedTarget else { return }
        hasReachedTarget = true
        locationManager.stopUpdatingLocation()
        HapticService.shared.triggerSuccess()
        speechService.speak(targetReachedSpeech)
    }

    private func distanceText(for distance: Double) -> String {
        String(format: L10n.audioNavigationDistanceFormat.current, distance)
    }

    private func recomputeAlignment() {
        guard let location = lastKnownLocation, let heading = lastKnownHeading else { return }
        let targetBearing = bearing(from: location.coordinate, to: targetLocation.coordinate)
        let diff = abs(heading - targetBearing)
        let error = min(diff, 360 - diff)
        let alignment = error / 180.0
        binding?.audioNavigationViewModel(self, didUpdateAlignment: alignment)
    }

    private func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return fmod((atan2(y, x) * 180 / .pi) + 360, 360)
    }
}

extension AudioNavigationViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastKnownLocation = latest
        let distance = latest.distance(from: targetLocation)
        didUpdateDistance(distance)
        recomputeAlignment()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        lastKnownHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        recomputeAlignment()
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
