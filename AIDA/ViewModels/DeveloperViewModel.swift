import CoreLocation

final class DeveloperViewModel {
    var screenTitle: String { L10n.developerTitle.current }
    var closeTitle: String { L10n.developerClose.current }
    var emptyMessage: String { L10n.developerNoMission.current }
    var exportTitle: String { L10n.developerExport.current }
    var testNavigationTitle: String { L10n.callTestNavigation.current }
    var testPhoneWalkingTitle: String { L10n.testPhoneWalkingTitle.current }
    var speedLabel: String { L10n.developerStatSpeed.current }
    var cadenceLabel: String { L10n.developerStatCadence.current }
    var pitchLabel: String { L10n.developerStatPitch.current }
    var placeholder: String { L10n.developerStatPlaceholder.current }
    var acquiringMessage: String { L10n.developerAcquiringGPS.current }

    var isRecording: Bool { SessionRecorder.shared.isRecording }
    var isAcquiringGPSFix: Bool { SessionRecorder.shared.isAcquiringGPSFix }

    var trackCoordinates: [CLLocationCoordinate2D] {
        SessionRecorder.shared.dataPoints.compactMap { point in
            guard let lat = point.latitude, let lon = point.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    var currentLocation: CLLocation? { SessionRecorder.shared.currentLocation }

    var speedDisplay: String {
        if let speed = SessionRecorder.shared.currentSpeed {
            return String(format: "%.2f", speed)
        }
        return placeholder
    }

    var cadenceDisplay: String {
        if let cadence = SessionRecorder.shared.currentCadence {
            return String(format: "%.0f", cadence)
        }
        return placeholder
    }

    var pitchDisplay: String {
        if let pitch = SessionRecorder.shared.currentPitch {
            return String(format: "%.1f", pitch)
        }
        return placeholder
    }

    func exportCSV() -> URL? {
        SessionRecorder.shared.exportCSV()
    }
}
