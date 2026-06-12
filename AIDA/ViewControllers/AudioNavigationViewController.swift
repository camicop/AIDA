import UIKit

final class AudioNavigationViewController: UIViewController {
    private let viewModel: AudioNavigationViewModel

    /// When set, a "target found" button is shown and this is called on tap
    /// (used when the screen is presented as a mission proximity step).
    var onTargetFound: (() -> Void)?

    private let pulseView = UIView()
    private let statusLabel = UILabel()
    private let distanceLabel = UILabel()
    private let hintLabel = UILabel()
    private let modeButton = UIButton(type: .system)
    private let targetFoundButton = UIButton(type: .system)
    private let debugTitleLabel = UILabel()
    private let debugSwitch = UISwitch()
    private let debugSlider = UISlider()
    private let debugStack = UIStackView()

    init(viewModel: AudioNavigationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        viewModel.binding = self
        setupViews()
        updateAppearanceForMode()
        enableDeveloperModeAccess()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPulse()
        viewModel.startTracking()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopTracking()
    }

    private func setupViews() {
        pulseView.backgroundColor = Theme.accent
        pulseView.layer.cornerRadius = 60
        pulseView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pulseView)

        statusLabel.text = viewModel.statusText
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 17, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        distanceLabel.text = viewModel.distancePlaceholder
        distanceLabel.textColor = .white
        distanceLabel.font = .systemFont(ofSize: 32, weight: .bold)
        distanceLabel.textAlignment = .center
        distanceLabel.adjustsFontSizeToFitWidth = true
        distanceLabel.minimumScaleFactor = 0.6
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(distanceLabel)

        hintLabel.text = viewModel.hintText
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        // Bottom controls: mode toggle, optional target-found, and debug sim.
        debugTitleLabel.text = viewModel.debugSimulatorLabel
        debugTitleLabel.textColor = .lightGray
        debugTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)

        debugSwitch.addTarget(self, action: #selector(debugSwitchChanged), for: .valueChanged)

        let switchRow = UIStackView(arrangedSubviews: [debugTitleLabel, debugSwitch])
        switchRow.axis = .horizontal
        switchRow.spacing = 12
        switchRow.alignment = .center

        debugSlider.minimumValue = 0
        debugSlider.maximumValue = 60
        debugSlider.value = 60
        debugSlider.isEnabled = false
        debugSlider.minimumTrackTintColor = Theme.accent
        debugSlider.addTarget(self, action: #selector(debugSliderChanged), for: .valueChanged)

        debugStack.axis = .vertical
        debugStack.spacing = 12
        debugStack.addArrangedSubview(switchRow)
        debugStack.addArrangedSubview(debugSlider)

        var modeConfig = UIButton.Configuration.gray()
        modeConfig.image = UIImage(systemName: "arrow.triangle.2.circlepath")
        modeConfig.imagePadding = 8
        modeConfig.cornerStyle = .large
        modeConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        modeButton.configuration = modeConfig
        modeButton.addTarget(self, action: #selector(didTapModeSwitch), for: .touchUpInside)

        let bottomStack = UIStackView()
        bottomStack.axis = .vertical
        bottomStack.spacing = 16
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.addArrangedSubview(debugStack)

        if onTargetFound != nil {
            var config = UIButton.Configuration.filled()
            config.title = L10n.proximityTargetFound.current
            config.baseBackgroundColor = Theme.accent
            config.baseForegroundColor = .white
            config.cornerStyle = .large
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
            targetFoundButton.configuration = config
            targetFoundButton.addTarget(self, action: #selector(didTapTargetFound), for: .touchUpInside)
            bottomStack.addArrangedSubview(targetFoundButton)
        }

        bottomStack.addArrangedSubview(modeButton)
        view.addSubview(bottomStack)

        NSLayoutConstraint.activate([
            pulseView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pulseView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            pulseView.widthAnchor.constraint(equalToConstant: 120),
            pulseView.heightAnchor.constraint(equalToConstant: 120),

            statusLabel.topAnchor.constraint(equalTo: pulseView.bottomAnchor, constant: 28),
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            distanceLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            distanceLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            distanceLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            hintLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 20),
            hintLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            bottomStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            bottomStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func updateAppearanceForMode() {
        let isCompass = viewModel.mode == .compass
        debugStack.isHidden = isCompass
        distanceLabel.isHidden = isCompass
        hintLabel.text = viewModel.hintText
        modeButton.configuration?.title = viewModel.modeButtonTitle
        if isCompass {
            UIView.animate(withDuration: 0.25) { self.view.backgroundColor = .black }
        }
    }

    private func startPulse() {
        UIView.animate(withDuration: 1.2,
                       delay: 0,
                       options: [.repeat, .autoreverse, .allowUserInteraction],
                       animations: {
            self.pulseView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.pulseView.alpha = 0.4
        })
    }

    @objc private func didTapModeSwitch() {
        viewModel.toggleMode()
    }

    @objc private func didTapTargetFound() {
        onTargetFound?()
    }

    @objc private func debugSwitchChanged() {
        let enabled = debugSwitch.isOn
        debugSlider.isEnabled = enabled
        viewModel.setDebugSimulatorEnabled(enabled)
        if enabled {
            viewModel.didUpdateDistance(Double(debugSlider.value))
        }
    }

    @objc private func debugSliderChanged() {
        viewModel.didUpdateDistance(Double(debugSlider.value))
    }
}

extension AudioNavigationViewController: AudioNavigationViewModelBinding {
    func audioNavigationViewModel(_ viewModel: AudioNavigationViewModel, didUpdateDistanceText text: String) {
        distanceLabel.text = text
    }

    func audioNavigationViewModel(_ viewModel: AudioNavigationViewModel, didUpdateAlignment alignment: Double) {
        // Color feedback only in color mode; compass mode stays dark.
        guard viewModel.mode == .color else { return }
        UIView.animate(withDuration: 0.2) {
            self.view.backgroundColor = directionColor(for: alignment)
        }
    }

    func audioNavigationViewModelDidChangeMode(_ viewModel: AudioNavigationViewModel) {
        updateAppearanceForMode()
    }
}

private func directionColor(for alignment: Double) -> UIColor {
    let clamped = max(0, min(1, alignment))
    let hue = CGFloat((1 - clamped) * (120.0 / 360.0))
    return UIColor(hue: hue, saturation: 0.7, brightness: 0.55, alpha: 1.0)
}
