import UIKit
import MapKit

final class DeveloperViewController: UIViewController {
    private let viewModel: DeveloperViewModel

    private let emptyLabel = UILabel()
    private let mapView = MKMapView()
    private let statsStack = UIStackView()
    private let acquiringBanner = UILabel()
    private let speedRow = StatRow()
    private let cadenceRow = StatRow()
    private let pitchRow = StatRow()
    private let exportButton = UIButton(type: .system)

    private var trackOverlay: MKPolyline?

    init(viewModel: DeveloperViewModel) {
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
            title: viewModel.closeTitle,
            style: .plain,
            target: self,
            action: #selector(didTapClose)
        )
        setupViews()
        SessionRecorder.shared.observer = self
        applyState()
    }

    private func setupViews() {
        emptyLabel.text = viewModel.emptyMessage
        emptyLabel.textColor = Theme.secondaryText
        emptyLabel.font = .systemFont(ofSize: 17)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        speedRow.configure(title: viewModel.speedLabel, value: viewModel.placeholder)
        cadenceRow.configure(title: viewModel.cadenceLabel, value: viewModel.placeholder)
        pitchRow.configure(title: viewModel.pitchLabel, value: viewModel.placeholder)

        acquiringBanner.text = viewModel.acquiringMessage
        acquiringBanner.font = .systemFont(ofSize: 14, weight: .semibold)
        acquiringBanner.textColor = .systemOrange
        acquiringBanner.textAlignment = .center
        acquiringBanner.isHidden = true

        statsStack.axis = .vertical
        statsStack.spacing = 6
        statsStack.addArrangedSubview(acquiringBanner)
        statsStack.addArrangedSubview(speedRow)
        statsStack.addArrangedSubview(cadenceRow)
        statsStack.addArrangedSubview(pitchRow)
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsStack)

        var config = UIButton.Configuration.filled()
        config.title = viewModel.exportTitle
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        exportButton.configuration = config
        exportButton.addTarget(self, action: #selector(didTapExport), for: .touchUpInside)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(exportButton)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: statsStack.topAnchor, constant: -16),

            statsStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            statsStack.bottomAnchor.constraint(equalTo: exportButton.topAnchor, constant: -16),

            exportButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            exportButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            exportButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.padding)
        ])
    }

    private func applyState() {
        let recording = viewModel.isRecording
        emptyLabel.isHidden = recording
        mapView.isHidden = !recording
        statsStack.isHidden = !recording
        exportButton.isEnabled = recording

        if recording {
            mapView.setUserTrackingMode(.follow, animated: true)
            refreshStats()
            refreshTrack()
        } else {
            mapView.setUserTrackingMode(.none, animated: false)
        }
        updateAcquiringBanner()
    }

    private func refreshStats() {
        speedRow.setValue(viewModel.speedDisplay)
        cadenceRow.setValue(viewModel.cadenceDisplay)
        pitchRow.setValue(viewModel.pitchDisplay)
    }

    private func updateAcquiringBanner() {
        acquiringBanner.isHidden = !viewModel.isAcquiringGPSFix
    }

    private func refreshTrack() {
        if let existing = trackOverlay {
            mapView.removeOverlay(existing)
            trackOverlay = nil
        }
        let coords = viewModel.trackCoordinates
        guard coords.count >= 2 else { return }
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        mapView.addOverlay(polyline)
        trackOverlay = polyline
    }

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapExport() {
        guard let url = viewModel.exportCSV() else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = exportButton
        activity.popoverPresentationController?.sourceRect = exportButton.bounds
        present(activity, animated: true)
    }
}

extension DeveloperViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = UIColor.systemPurple
        renderer.lineWidth = 4
        renderer.lineCap = .round
        renderer.lineJoin = .round
        return renderer
    }
}

extension DeveloperViewController: SessionRecorderObserver {
    func sessionRecorder(_ recorder: SessionRecorder, didAppend point: SessionRecorder.DataPoint) {
        refreshStats()
        refreshTrack()
        updateAcquiringBanner()
    }

    func sessionRecorderDidChangeRecordingState(_ recorder: SessionRecorder) {
        applyState()
    }
}

private final class StatRow: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.cardBackground
        layer.cornerRadius = 10
        layoutMargins = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = Theme.secondaryText
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        valueLabel.textAlignment = .right

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }

    func setValue(_ value: String) {
        valueLabel.text = value
    }
}
