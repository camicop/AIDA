import UIKit
import MapKit
import CoreLocation

final class MapViewController: UIViewController {
    private let viewModel: MapViewModel
    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()

    private let circleOverlayView = CircleOverlayView()
    private let bottomPanel = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let diameterLabel = UILabel()
    private let disclaimerLabel = UILabel()
    private let confirmButton = UIButton(type: .system)

    private let circleScreenDiameter: CGFloat = 240

    private var hasRequestedAuth = false
    private var hasZoomedToUser = false
    private var hasAppliedInitialRegion = false

    init(viewModel: MapViewModel) {
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        setupMap()
        setupBottomPanel()
        setupCircleOverlay()

        if viewModel.initialArea == nil {
            let initialRegion = MKCoordinateRegion(
                center: Zone.trentoCenter,
                latitudinalMeters: 1500,
                longitudinalMeters: 1500
            )
            mapView.setRegion(initialRegion, animated: false)
        } else {
            // Skip auto-recentering on the user when we already have a saved area.
            hasZoomedToUser = true
        }
        mapView.addAnnotations(viewModel.zones.map { ZoneAnnotation(zone: $0) })

        enableDeveloperModeAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        circleOverlayView.center = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
        applyInitialAreaRegionIfNeeded()
        updateDiameter()
    }

    private func applyInitialAreaRegionIfNeeded() {
        guard !hasAppliedInitialRegion,
              let area = viewModel.initialArea,
              mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
        hasAppliedInitialRegion = true

        // Pick a region whose visible span is scaled so that the on-screen circle
        // (240pt) matches the stored area's geographic diameter.
        let diameterMeters = area.radiusMeters * 2
        let latMeters = diameterMeters * mapView.bounds.height / circleScreenDiameter
        let lonMeters = diameterMeters * mapView.bounds.width / circleScreenDiameter
        let region = MKCoordinateRegion(
            center: area.center,
            latitudinalMeters: latMeters,
            longitudinalMeters: lonMeters
        )
        mapView.setRegion(region, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasRequestedAuth else { return }
        hasRequestedAuth = true
        evaluateAuthorization()
    }

    private func setupMap() {
        mapView.delegate = self
        mapView.register(ZoneAnnotationView.self, forAnnotationViewWithReuseIdentifier: ZoneAnnotationView.reuseID)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupCircleOverlay() {
        circleOverlayView.bounds = CGRect(x: 0, y: 0, width: circleScreenDiameter, height: circleScreenDiameter)
        circleOverlayView.isUserInteractionEnabled = false
        mapView.addSubview(circleOverlayView)
    }

    private func setupBottomPanel() {
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomPanel)

        diameterLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        diameterLabel.textColor = Theme.primaryText
        diameterLabel.textAlignment = .center
        diameterLabel.text = " "

        disclaimerLabel.font = .systemFont(ofSize: 13)
        disclaimerLabel.textColor = Theme.secondaryText
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.text = viewModel.diameterDisclaimer

        var config = UIButton.Configuration.filled()
        config.title = viewModel.confirmAreaTitle
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        confirmButton.configuration = config
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [diameterLabel, disclaimerLabel, confirmButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(14, after: disclaimerLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: bottomPanel.contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: bottomPanel.contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bottomPanel.contentView.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.padding)
        ])
    }

    // MARK: - Geometry / diameter

    private func currentRadiusMeters() -> Double {
        guard mapView.bounds.width > 0 else { return 0 }
        let centerPoint = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
        let edgePoint = CGPoint(x: centerPoint.x + circleScreenDiameter / 2, y: centerPoint.y)
        let centerCoord = mapView.convert(centerPoint, toCoordinateFrom: mapView)
        let edgeCoord = mapView.convert(edgePoint, toCoordinateFrom: mapView)
        let centerLoc = CLLocation(latitude: centerCoord.latitude, longitude: centerCoord.longitude)
        let edgeLoc = CLLocation(latitude: edgeCoord.latitude, longitude: edgeCoord.longitude)
        return centerLoc.distance(from: edgeLoc)
    }

    private func updateDiameter() {
        let radius = currentRadiusMeters()
        let diameter = radius * 2
        let isValid = diameter <= viewModel.maxDiameterMeters
        diameterLabel.text = viewModel.diameterLabel(forDiameterMeters: diameter)
        circleOverlayView.setValid(isValid)
        confirmButton.isEnabled = isValid
    }

    // MARK: - Permission handling

    private func evaluateAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showDeniedAlert()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            showDeniedAlert()
        }
    }

    private func startLocationUpdates() {
        mapView.showsUserLocation = true
        locationManager.startUpdatingLocation()
    }

    private func showDeniedAlert() {
        let alert = UIAlertController(
            title: viewModel.gpsDeniedTitle,
            message: viewModel.gpsDeniedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: viewModel.openSettingsTitle, style: .default) { [weak self] _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            self?.viewModel.didCancel()
        })
        alert.addAction(UIAlertAction(title: viewModel.cancelTitle, style: .cancel) { [weak self] _ in
            self?.viewModel.didCancel()
        })
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func didTapConfirm() {
        let radius = currentRadiusMeters()
        let centerPoint = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
        let centerCoord = mapView.convert(centerPoint, toCoordinateFrom: mapView)
        viewModel.didConfirmArea(center: centerCoord, radiusMeters: radius)
    }

    @objc private func didTapCancel() {
        viewModel.didCancel()
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        guard let zoneAnnotation = annotation as? ZoneAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: ZoneAnnotationView.reuseID,
            for: zoneAnnotation
        ) as! ZoneAnnotationView
        view.configure(checkpointCount: zoneAnnotation.zone.checkpointCount)
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let zoneAnnotation = view.annotation as? ZoneAnnotation else { return }
        mapView.setCenter(zoneAnnotation.coordinate, animated: true)
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        updateDiameter()
    }
}

extension MapViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            showDeniedAlert()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasZoomedToUser, let location = locations.last else { return }
        hasZoomedToUser = true
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 1500,
            longitudinalMeters: 1500
        )
        mapView.setRegion(region, animated: true)
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore intermittent failures; map stays on the previous region.
    }
}

// MARK: - Annotation

final class ZoneAnnotation: NSObject, MKAnnotation {
    let zone: Zone
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(zone: Zone) {
        self.zone = zone
        self.coordinate = zone.center
        self.title = zone.name.current
        self.subtitle = String(format: L10n.mapCheckpointsCountFormat.current, zone.checkpointCount)
        super.init()
    }
}

final class ZoneAnnotationView: MKAnnotationView {
    static let reuseID = "ZoneAnnotationView"

    private let badge = UIView()
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = true
        backgroundColor = .clear
        addSubview(badge)
        badge.addSubview(label)
        badge.layer.borderColor = UIColor.white.cgColor
        badge.layer.borderWidth = 2
        label.textColor = .white
        label.textAlignment = .center
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(checkpointCount: Int) {
        let size: CGFloat
        let color: UIColor
        let fontSize: CGFloat
        if checkpointCount >= 4 {
            size = 48
            color = UIColor(red: 0.42, green: 0.18, blue: 0.78, alpha: 1.0)
            fontSize = 18
        } else if checkpointCount >= 2 {
            size = 40
            color = UIColor(red: 0.55, green: 0.30, blue: 0.82, alpha: 1.0)
            fontSize = 16
        } else {
            size = 32
            color = UIColor(red: 0.62, green: 0.38, blue: 0.86, alpha: 1.0)
            fontSize = 15
        }

        badge.backgroundColor = color
        badge.layer.cornerRadius = size / 2
        label.text = checkpointCount > 1 ? "\(checkpointCount)" : "?"
        label.font = .systemFont(ofSize: fontSize, weight: .bold)

        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        bounds = rect
        badge.frame = rect
        label.frame = rect
        centerOffset = .zero
    }
}

// MARK: - Circle overlay

private final class CircleOverlayView: UIView {
    private let shape = CAShapeLayer()
    private var isValid: Bool = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        shape.lineWidth = 3
        layer.addSublayer(shape)
        applyColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = shape.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        shape.path = UIBezierPath(ovalIn: rect).cgPath
    }

    func setValid(_ valid: Bool) {
        guard isValid != valid else { return }
        isValid = valid
        applyColor()
    }

    private func applyColor() {
        let stroke: UIColor = isValid ? .systemGreen : .systemRed
        shape.strokeColor = stroke.cgColor
        shape.fillColor = stroke.withAlphaComponent(0.18).cgColor
    }
}
