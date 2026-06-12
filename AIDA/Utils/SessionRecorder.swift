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
        var latitude: Double?
        var longitude: Double?
        var speedMS: Double?
        var cadenceSpm: Double?
        var pitchDeg: Double?
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

    var isAcquiringGPSFix: Bool { isRecording && currentLocation == nil }

    private let maxLocationAgeSeconds: TimeInterval = 5
    private let maxHorizontalAccuracyMeters: CLLocationAccuracy = 20

    private var pendingEvent: String?
    /// When the most recent GPS point was recorded; used to enrich it in place
    /// rather than appending a duplicate on the next timer tick.
    private var lastGPSPointTime: Date?

    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()

    // Samples sensors independently of GPS so pitch/cadence keep flowing indoors.
    private let sampleInterval: TimeInterval = 0.5
    private let sampleQueue = DispatchQueue(label: "SessionRecorder.sampleTimer", qos: .utility)
    private var sampleTimer: DispatchSourceTimer?

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
        lastGPSPointTime = nil

        locationManager.startUpdatingLocation()
        startPedometer()
        startMotion()
        startSampleTimer()

        observer?.sessionRecorderDidChangeRecordingState(self)
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        stopSampleTimer()
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        observer?.sessionRecorderDidChangeRecordingState(self)
    }

    // MARK: - Sampling timer

    private func startSampleTimer() {
        let timer = DispatchSource.makeTimerSource(queue: sampleQueue)
        timer.schedule(deadline: .now() + sampleInterval, repeating: sampleInterval)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in self?.sampleTick() }
        }
        sampleTimer = timer
        timer.resume()
    }

    private func stopSampleTimer() {
        sampleTimer?.cancel()
        sampleTimer = nil
    }

    /// Fires every 0.5s regardless of GPS. Enriches a just-recorded GPS point
    /// with the latest pitch/cadence, or appends a new point built from the
    /// current sensor values (with empty lat/lon when there's no fix).
    private func sampleTick() {
        guard isRecording else { return }
        let now = Date()

        if let gpsTime = lastGPSPointTime,
           now.timeIntervalSince(gpsTime) <= sampleInterval,
           let lastIndex = dataPoints.indices.last {
            dataPoints[lastIndex].pitchDeg = currentPitch
            dataPoints[lastIndex].cadenceSpm = currentCadence
            observer?.sessionRecorder(self, didAppend: dataPoints[lastIndex])
            return
        }

        let point = DataPoint(
            timestamp: now,
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude,
            speedMS: currentSpeed,
            cadenceSpm: currentCadence,
            pitchDeg: currentPitch,
            event: nil
        )
        dataPoints.append(point)
        observer?.sessionRecorder(self, didAppend: point)
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

        // Missing values are written as empty strings so pandas reads them as NaN.
        func field(_ value: Double?, _ format: String) -> String {
            value.map { String(format: format, $0) } ?? ""
        }

        // Applied only at export time, on the final array, as the last step
        // before writing.
        // 1. Sort chronologically by Date (GPS callbacks can carry an earlier
        //    fix time than a timer point recorded before them).
        let sortedPoints = dataPoints.sorted { $0.timestamp < $1.timestamp }

        // 2. Drop near-duplicates AFTER sorting, so duplicates that only become
        //    adjacent once ordered are caught: timestamp within 10 ms of the
        //    previous kept row AND identical speed/cadence/pitch.
        var exportPoints: [DataPoint] = []
        for point in sortedPoints {
            if let previous = exportPoints.last {
                let withinTenMs = abs(point.timestamp.timeIntervalSince(previous.timestamp)) < 0.01
                let sameValues = point.speedMS == previous.speedMS
                    && point.cadenceSpm == previous.cadenceSpm
                    && point.pitchDeg == previous.pitchDeg
                if withinTenMs && sameValues { continue }
            }
            exportPoints.append(point)
        }

        var csv = "timestamp,latitude,longitude,speed_ms,cadence_spm,pitch_deg,event\n"
        for point in exportPoints {
            let columns = [
                iso.string(from: point.timestamp),
                field(point.latitude, "%.6f"),
                field(point.longitude, "%.6f"),
                field(point.speedMS, "%.3f"),
                field(point.cadenceSpm, "%.2f"),
                field(point.pitchDeg, "%.2f"),
                point.event ?? ""
            ]
            csv += columns.joined(separator: ",") + "\n"
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

        currentLocation = location
        let event = pendingEvent
        pendingEvent = nil
        let point = DataPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            // Speed comes from the pedometer (see startPedometer), not from GPS.
            speedMS: currentSpeed,
            cadenceSpm: currentCadence,
            pitchDeg: currentPitch,
            event: event
        )
        dataPoints.append(point)
        lastGPSPointTime = Date()
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
