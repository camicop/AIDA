import Foundation
import CoreLocation
import CoreMotion

@MainActor
protocol SessionRecorderObserver: AnyObject {
    func sessionRecorder(_ recorder: SessionRecorder, didAppend point: SessionRecorder.DataPoint)
    func sessionRecorderDidChangeRecordingState(_ recorder: SessionRecorder)
}

@MainActor
final class SessionRecorder: NSObject {
    static let shared = SessionRecorder()

    struct DataPoint {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let speedMS: Double
        let cadenceSpm: Double?
        let pitchDeg: Double?
        var event: String?
    }

    weak var observer: SessionRecorderObserver?

    private(set) var isRecording: Bool = false
    private(set) var dataPoints: [DataPoint] = []

    private(set) var currentCadence: Double?
    private(set) var currentPitch: Double?
    private(set) var currentLocation: CLLocation?

    /// Speed in m/s derived from the pedometer's pace, not GPS.
    private(set) var currentSpeed: Double?

    var isAcquiringGPSFix: Bool { isRecording && dataPoints.isEmpty }

    private let maxLocationAgeSeconds: TimeInterval = 5
    private let maxHorizontalAccuracyMeters: CLLocationAccuracy = 20

    private var pendingEvent: String?

    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .fitness
    }

    // MARK: - Lifecycle

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        dataPoints.removeAll()
        currentCadence = nil
        currentPitch = nil
        currentLocation = nil
        currentSpeed = nil
        pendingEvent = nil

        locationManager.startUpdatingLocation()
        startPedometer()
        startMotion()

        observer?.sessionRecorderDidChangeRecordingState(self)
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        observer?.sessionRecorderDidChangeRecordingState(self)
    }

    func logEvent(_ event: String) {
        if dataPoints.isEmpty {
            pendingEvent = event
        } else {
            dataPoints[dataPoints.count - 1].event = event
        }
    }

    // MARK: - Export

    func exportCSV() -> URL? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var csv = "timestamp,latitude,longitude,speed_ms,cadence_spm,pitch_deg,event\n"
        for point in dataPoints {
            let cadence = point.cadenceSpm.map { String(format: "%.2f", $0) } ?? ""
            let pitch = point.pitchDeg.map { String(format: "%.2f", $0) } ?? ""
            let event = point.event ?? ""
            csv += "\(iso.string(from: point.timestamp)),"
            csv += "\(point.latitude),\(point.longitude),"
            csv += "\(String(format: "%.3f", point.speedMS)),"
            csv += "\(cadence),\(pitch),\(event)\n"
        }

        let nameFormatter = DateFormatter()
        nameFormatter.locale = Locale(identifier: "en_US_POSIX")
        nameFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "AIDA_session_\(nameFormatter.string(from: Date())).csv"

        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = documents.appendingPathComponent(filename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Sensors

    private func startPedometer() {
        guard CMPedometer.isCadenceAvailable() || CMPedometer.isPaceAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let data = data else { return }
            let cadenceSpm = data.currentCadence.map { $0.doubleValue * 60 }
            // currentPace is seconds per meter; invert for m/s. A pace of 0 or
            // a missing value means the user is not moving.
            let speedMS: Double?
            if let pace = data.currentPace?.doubleValue, pace > 0 {
                speedMS = 1 / pace
            } else {
                speedMS = nil
            }
            Task { @MainActor in
                if let cadenceSpm = cadenceSpm {
                    self?.currentCadence = cadenceSpm
                }
                self?.currentSpeed = speedMS
            }
        }
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            let pitchDeg = motion.attitude.pitch * 180 / .pi
            Task { @MainActor in
                self?.currentPitch = pitchDeg
            }
        }
    }

    private func handleLocation(_ location: CLLocation) {
        let age = Date().timeIntervalSince(location.timestamp)
        guard age <= maxLocationAgeSeconds else { return }
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxHorizontalAccuracyMeters else { return }

        // Speed comes from the pedometer (see startPedometer), not from GPS.
        let speed = currentSpeed ?? 0

        currentLocation = location
        let event = pendingEvent
        pendingEvent = nil
        let point = DataPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedMS: speed,
            cadenceSpm: currentCadence,
            pitchDeg: currentPitch,
            event: event
        )
        dataPoints.append(point)
        observer?.sessionRecorder(self, didAppend: point)
    }
}

extension SessionRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.handleLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Intermittent GPS failures are non-fatal for recording.
    }
}
