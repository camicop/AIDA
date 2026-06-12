import UIKit

final class HapticService {
    static let shared = HapticService()

    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private var pulseTimer: Timer?
    private var successTimer: Timer?

    private init() {}

    func updateGuidance(forDistance distance: Double) {
        let clamped = max(3.0, min(50.0, distance))
        let normalized = (clamped - 3.0) / (50.0 - 3.0)
        let interval = 0.12 + normalized * (1.4 - 0.12)
        schedulePulse(interval: interval)
    }

    /// Pulse frequency driven by heading alignment: `alignment` 0 = facing the
    /// target (fast pulses), 1 = facing away (slow pulses). The curve is flat
    /// near 0 so slightly-off directions stay nearly as fast as the correct one,
    /// and only larger deviations slow down noticeably.
    func updateHeadingGuidance(alignment: Double) {
        let clamped = max(0.0, min(1.0, alignment))
        let curved = pow(clamped, 1.8)
        let interval = 0.08 + curved * (1.3 - 0.08)
        schedulePulse(interval: interval)
    }

    func stop() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        successTimer?.invalidate()
        successTimer = nil
    }

    func triggerSuccess() {
        stop()
        notification.prepare()
        notification.notificationOccurred(.success)
        heavyImpact.prepare()

        var count = 0
        successTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.heavyImpact.impactOccurred(intensity: 1.0)
            count += 1
            if count >= 8 {
                timer.invalidate()
                self.successTimer = nil
            }
        }
    }

    private func schedulePulse(interval: TimeInterval) {
        pulseTimer?.invalidate()
        mediumImpact.prepare()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.mediumImpact.impactOccurred()
        }
    }
}
