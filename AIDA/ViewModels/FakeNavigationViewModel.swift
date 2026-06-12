import CoreLocation

final class FakeNavigationViewModel {
    var screenTitle: String { L10n.navScreenTitle.current }
    var closeTitle: String { L10n.developerClose.current }
    var detectionMessage: String { L10n.phoneWalkingMessage.current }
    var popupText: String { L10n.phoneWalkingPopup.current }

    let center = CLLocationCoordinate2D(latitude: 46.0664, longitude: 11.1213)
    /// Target ~150 m north of center.
    var targetCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: center.latitude + 150.0 / 111_320.0,
                               longitude: center.longitude)
    }

    func randomHint() -> String {
        (L10n.navHints.randomElement() ?? L10n.navHints[0]).current
    }

    func pitchText(_ degrees: Double) -> String {
        String(format: L10n.navPitchFormat.current, degrees)
    }

    func zoneTimerText(_ seconds: Double) -> String {
        String(format: L10n.navZoneTimerFormat.current, seconds)
    }
}
