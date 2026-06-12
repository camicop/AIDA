import UIKit
import MapKit

/// Debug screen that fakes turn-by-turn navigation while detecting the user
/// "walking with their eyes on the phone" via device pitch.
final class FakeNavigationViewController: UIViewController {
    private let viewModel: FakeNavigationViewModel
    private let detector = PhoneWalkingDetector()
    private let speechService = SpeechService()

    private let mapView = MKMapView()
    private let graphView = PitchGraphView()
    private let pitchLabel = UILabel()
    private let zoneLabel = UILabel()
    private let muteButton = UIBarButtonItem()

    private var voiceEnabled = true
    private var hintTimer: Timer?
    private var currentBubble: UIView?

    init(viewModel: FakeNavigationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = viewModel.screenTitle
        setupNavBar()
        setupViews()
        setupDetector()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        detector.voiceEnabled = voiceEnabled
        detector.start()
        if voiceEnabled { startHints() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        detector.stop()
        stopHints()
        speechService.stop()
    }

    // MARK: - Setup

    private func setupNavBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: viewModel.closeTitle,
            style: .plain,
            target: self,
            action: #selector(didTapClose)
        )
        muteButton.target = self
        muteButton.action = #selector(didTapMute)
        updateMuteButton()
        navigationItem.rightBarButtonItem = muteButton
    }

    private func setupViews() {
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        let region = MKCoordinateRegion(center: viewModel.center,
                                        latitudinalMeters: 500,
                                        longitudinalMeters: 500)
        mapView.setRegion(region, animated: false)
        mapView.addAnnotation(NavAnnotation(coordinate: viewModel.targetCoordinate, kind: .target))
        mapView.addAnnotation(NavAnnotation(coordinate: viewModel.center, kind: .user))

        graphView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(graphView)

        pitchLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        pitchLabel.textColor = .systemGreen
        pitchLabel.textAlignment = .center
        pitchLabel.text = viewModel.pitchText(0)
        pitchLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pitchLabel)

        zoneLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        zoneLabel.textColor = Theme.secondaryText
        zoneLabel.textAlignment = .center
        zoneLabel.text = viewModel.zoneTimerText(0)
        zoneLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(zoneLabel)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.6),

            graphView.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 16),
            graphView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            graphView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            graphView.heightAnchor.constraint(equalToConstant: 120),

            pitchLabel.topAnchor.constraint(equalTo: graphView.bottomAnchor, constant: 12),
            pitchLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            pitchLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            zoneLabel.topAnchor.constraint(equalTo: pitchLabel.bottomAnchor, constant: 6),
            zoneLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            zoneLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    private func setupDetector() {
        detector.onPitch = { [weak self] pitch in
            self?.graphView.addSample(pitch)
            self?.updatePitchLabel(pitch)
        }
        detector.onZoneElapsed = { [weak self] seconds in
            self?.zoneLabel.text = self?.viewModel.zoneTimerText(seconds)
        }
        detector.onTriggered = { [weak self] in
            self?.handleDetection()
        }
    }

    // MARK: - Pitch label

    private func updatePitchLabel(_ pitch: Double) {
        pitchLabel.text = viewModel.pitchText(pitch)
        let inZone = pitch >= 0 && pitch <= 70
        pitchLabel.textColor = inZone ? .systemRed : .systemGreen
    }

    // MARK: - Hints

    private func startHints() {
        stopHints()
        hintTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.sendHint()
        }
    }

    private func stopHints() {
        hintTimer?.invalidate()
        hintTimer = nil
    }

    private func sendHint() {
        guard voiceEnabled else { return }
        let hint = viewModel.randomHint()
        showAgentBubble(hint)
        speechService.speak(hint)
    }

    // MARK: - Detection

    private func handleDetection() {
        showDetectionOverlay()
        speechService.speak(viewModel.detectionMessage)
        SessionRecorder.shared.logEvent("PHONE_WALKING_DETECTED")
    }

    // MARK: - Agent message bubble (bottom of the map)

    private func showAgentBubble(_ text: String) {
        currentBubble?.removeFromSuperview()

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15)
        label.textColor = Theme.primaryText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let bubble = UIView()
        bubble.backgroundColor = Theme.cardBackground
        bubble.layer.cornerRadius = 14
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = 0.2
        bubble.layer.shadowRadius = 6
        bubble.layer.shadowOffset = CGSize(width: 0, height: 2)
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(label)
        view.addSubview(bubble)
        currentBubble = bubble

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),

            bubble.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            bubble.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -12),
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: mapView.leadingAnchor, constant: 16),
            bubble.trailingAnchor.constraint(lessThanOrEqualTo: mapView.trailingAnchor, constant: -16)
        ])

        bubble.alpha = 0
        bubble.transform = CGAffineTransform(translationX: 0, y: 16)
        UIView.animate(withDuration: 0.3) {
            bubble.alpha = 1
            bubble.transform = .identity
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self, weak bubble] in
            guard let bubble, self?.currentBubble === bubble else { return }
            UIView.animate(withDuration: 0.3, animations: { bubble.alpha = 0 }) { _ in
                bubble.removeFromSuperview()
            }
        }
    }

    // MARK: - Detection overlay (large, covers the map, dismissed via X)

    private var detectionOverlay: UIView?

    private func showDetectionOverlay() {
        guard detectionOverlay == nil else { return }

        // Translucent dim over the map (the graph/countdown below stay visible).
        let dim = UIView()
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        dim.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dim)
        detectionOverlay = dim

        let icon = UIImageView(image: UIImage(systemName: "eye.slash.fill"))
        icon.tintColor = .systemOrange
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 52)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = viewModel.popupText
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.text = viewModel.detectionMessage
        bodyLabel.font = .systemFont(ofSize: 16)
        bodyLabel.textColor = Theme.secondaryText
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 28)), for: .normal)
        closeButton.tintColor = Theme.secondaryText
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(didTapDismissOverlay), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [icon, titleLabel, bodyLabel])
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = Theme.background
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)
        card.addSubview(closeButton)
        dim.addSubview(card)

        NSLayoutConstraint.activate([
            dim.topAnchor.constraint(equalTo: mapView.topAnchor),
            dim.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
            dim.leadingAnchor.constraint(equalTo: mapView.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),

            card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: dim.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: dim.trailingAnchor, constant: -20),

            closeButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),

            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 36),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24)
        ])

        dim.alpha = 0
        UIView.animate(withDuration: 0.25) { dim.alpha = 1 }
    }

    @objc private func didTapDismissOverlay() {
        guard let dim = detectionOverlay else { return }
        detectionOverlay = nil
        UIView.animate(withDuration: 0.25, animations: { dim.alpha = 0 }, completion: { _ in
            dim.removeFromSuperview()
        })
        // Resume detection 5 seconds after the overlay is dismissed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.detector.resumeDetection()
        }
    }

    // MARK: - Actions

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapMute() {
        voiceEnabled.toggle()
        detector.voiceEnabled = voiceEnabled
        updateMuteButton()
        if voiceEnabled {
            startHints()
        } else {
            stopHints()
            speechService.stop()
        }
    }

    private func updateMuteButton() {
        let name = voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
        muteButton.image = UIImage(systemName: name)
    }
}

// MARK: - Map annotations

private final class NavAnnotation: NSObject, MKAnnotation {
    enum Kind { case target, user }
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
    }
}

extension FakeNavigationViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let nav = annotation as? NavAnnotation else { return nil }
        switch nav.kind {
        case .target:
            let id = "target"
            let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            marker.annotation = annotation
            marker.markerTintColor = .systemPurple
            marker.glyphText = "?"
            return marker
        case .user:
            let id = "user"
            let dot = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            dot.annotation = annotation
            dot.image = Self.userDotImage
            return dot
        }
    }

    private static let userDotImage: UIImage = {
        let size = CGSize(width: 16, height: 16)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            UIColor.white.setStroke()
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            context.cgContext.setLineWidth(2)
            context.cgContext.fillEllipse(in: rect)
            context.cgContext.strokeEllipse(in: rect)
        }
    }()
}
