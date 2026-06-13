import Foundation
import CoreMotion

/// Detects the user walking while staring at the phone: device pitch held in the
/// "looking down at a held phone" range for a sustained period (while the voice
/// navigator is on). Owns its own CMMotionManager, separate from SessionRecorder.
@MainActor
final class PhoneWalkingDetector {
    /// Emits the current pitch in degrees at ~10 Hz (for the live graph/label).
    var onPitch: ((Double) -> Void)?
    /// Emits how long the pitch has been continuously in the detection zone
    /// (0 when outside the zone / paused / voice off). Resets on leaving the zone.
    var onZoneElapsed: ((Double) -> Void)?
    /// Fires once when the sustained-pitch condition is met. Detection then
    /// pauses itself until `resumeDetection()` is called.
    var onTriggered: (() -> Void)?

    /// Detection only counts while the voice navigator is enabled.
    var voiceEnabled: Bool = true

    private let motionManager = CMMotionManager()
    private let sampleInterval: TimeInterval = 0.1
    private let lowerBound: Double = 0
    private let upperBound: Double = 70
    private let requiredSeconds: TimeInterval = 10

    private var inZoneSince: Date?
    private var isPaused = false

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        inZoneSince = nil
        isPaused = false
        motionManager.deviceMotionUpdateInterval = sampleInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let pitchDegrees = motion.attitude.pitch * 180 / .pi
            // Delivered on the main queue; hop onto the main actor to touch state.
            MainActor.assumeIsolated {
                self?.handle(pitch: pitchDegrees)
            }
        }
    }

    func stop() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        inZoneSince = nil
        isPaused = false
    }

    func pauseDetection() {
        isPaused = true
        inZoneSince = nil
    }

    func resumeDetection() {
        isPaused = false
        inZoneSince = nil
    }

    private func handle(pitch: Double) {
        onPitch?(pitch)

        let inZone = pitch >= lowerBound && pitch <= upperBound
        guard !isPaused, voiceEnabled, inZone else {
            inZoneSince = nil
            onZoneElapsed?(0)
            return
        }

        if inZoneSince == nil {
            inZoneSince = Date()
        }
        let elapsed = Date().timeIntervalSince(inZoneSince ?? Date())
        if elapsed >= requiredSeconds {
            // Pause immediately; the screen schedules the resume.
            isPaused = true
            inZoneSince = nil
            onZoneElapsed?(0)
            onTriggered?()
        } else {
            onZoneElapsed?(elapsed)
        }
    }
}
