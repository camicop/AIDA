import UIKit

/// Full-screen call UI. Reflects `CallSession` state; mute/speaker are forwarded
/// straight to the session, while minimize is handled by the coordinator.
final class ActiveCallViewController: UIViewController {
    private let session: CallSession
    var onMinimize: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let timerLabel = UILabel()
    private let waveform = WaveformIndicatorView(barCount: 5)
    private let answerLabel = UILabel()
    private let micButton = UIButton(type: .system)

    private let muteButton = UIButton(type: .system)
    private let speakerButton = UIButton(type: .system)
    private let hangUpButton = UIButton(type: .system)
    private let minimizeButton = UIButton(type: .system)

    init(session: CallSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupViews()
        render()
    }

    private func setupViews() {
        avatarView.image = UIImage(systemName: session.agentIconName)
        avatarView.tintColor = Theme.accent
        avatarView.contentMode = .scaleAspectFit
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.text = session.agentName
        nameLabel.font = .systemFont(ofSize: 30, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.textColor = Theme.primaryText

        statusLabel.font = .systemFont(ofSize: 17)
        statusLabel.textColor = Theme.secondaryText
        statusLabel.textAlignment = .center

        timerLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        timerLabel.textColor = Theme.secondaryText
        timerLabel.textAlignment = .center

        let headerStack = UIStackView(arrangedSubviews: [avatarView, nameLabel, statusLabel, timerLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 10
        headerStack.alignment = .center
        headerStack.setCustomSpacing(18, after: avatarView)
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        waveform.translatesAutoresizingMaskIntoConstraints = false

        answerLabel.font = .systemFont(ofSize: 16, weight: .medium)
        answerLabel.textColor = Theme.primaryText
        answerLabel.textAlignment = .center
        answerLabel.numberOfLines = 0
        answerLabel.isHidden = true
        answerLabel.translatesAutoresizingMaskIntoConstraints = false

        var micConfig = UIButton.Configuration.filled()
        micConfig.image = UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28))
        micConfig.baseForegroundColor = .white
        micConfig.baseBackgroundColor = Theme.accent
        micConfig.cornerStyle = .capsule
        micConfig.contentInsets = NSDirectionalEdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
        micButton.configuration = micConfig
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.addTarget(self, action: #selector(didTapMic), for: .touchUpInside)
        micButton.widthAnchor.constraint(equalToConstant: 76).isActive = true
        micButton.heightAnchor.constraint(equalToConstant: 76).isActive = true

        configureControl(muteButton, systemImage: "mic.slash.fill", tint: Theme.primaryText, background: Theme.cardBackground)
        muteButton.addTarget(self, action: #selector(didTapMute), for: .touchUpInside)

        configureControl(speakerButton, systemImage: "speaker.wave.2.fill", tint: Theme.primaryText, background: Theme.cardBackground)
        speakerButton.addTarget(self, action: #selector(didTapSpeaker), for: .touchUpInside)

        configureControl(hangUpButton, systemImage: "phone.down.fill", tint: .white, background: .systemRed)
        hangUpButton.addTarget(self, action: #selector(didTapHangUp), for: .touchUpInside)

        let controlsStack = UIStackView(arrangedSubviews: [muteButton, speakerButton, hangUpButton])
        controlsStack.axis = .horizontal
        controlsStack.distribution = .equalSpacing
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        var minimizeConfig = UIButton.Configuration.plain()
        minimizeConfig.image = UIImage(systemName: "chevron.down")
        minimizeConfig.baseForegroundColor = Theme.secondaryText
        minimizeButton.configuration = minimizeConfig
        minimizeButton.accessibilityLabel = L10n.activeCallMinimize.current
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.addTarget(self, action: #selector(didTapMinimize), for: .touchUpInside)

        view.addSubview(minimizeButton)
        view.addSubview(headerStack)
        view.addSubview(waveform)
        view.addSubview(answerLabel)
        view.addSubview(micButton)
        view.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            minimizeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            minimizeButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),

            avatarView.widthAnchor.constraint(equalToConstant: 120),
            avatarView.heightAnchor.constraint(equalToConstant: 120),

            headerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            headerStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),

            waveform.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waveform.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 10),
            waveform.heightAnchor.constraint(equalToConstant: 44),
            waveform.widthAnchor.constraint(equalToConstant: 80),

            answerLabel.topAnchor.constraint(equalTo: waveform.bottomAnchor, constant: 28),
            answerLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            answerLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            micButton.topAnchor.constraint(equalTo: answerLabel.bottomAnchor, constant: 14),
            micButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            controlsStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 24),
            controlsStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -24),
            controlsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    private func configureControl(_ button: UIButton, systemImage: String, tint: UIColor, background: UIColor) {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: systemImage, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24))
        config.baseForegroundColor = tint
        config.baseBackgroundColor = background
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 64).isActive = true
        button.heightAnchor.constraint(equalToConstant: 64).isActive = true
    }

    // MARK: - Rendering

    /// Re-reads all state from the session. Called by the coordinator on any change.
    func render() {
        statusLabel.text = session.statusText
        timerLabel.text = session.durationText

        muteButton.configuration?.baseBackgroundColor = session.isMuted ? Theme.accent : Theme.cardBackground
        muteButton.configuration?.baseForegroundColor = session.isMuted ? .white : Theme.primaryText
        muteButton.accessibilityLabel = L10n.activeCallMute.current

        speakerButton.configuration?.baseBackgroundColor = session.isSpeaker ? Theme.accent : Theme.cardBackground
        speakerButton.configuration?.baseForegroundColor = session.isSpeaker ? .white : Theme.primaryText
        speakerButton.accessibilityLabel = L10n.activeCallSpeaker.current

        if session.isSpeaking {
            waveform.startAnimating()
        } else {
            waveform.stopAnimating()
        }

        renderAnswerState()
    }

    private func renderAnswerState() {
        let listening = session.isListening
        let awaiting = session.isAwaitingAnswer

        // The mic is always available so the user can speak to the agent anytime;
        // the label/pulse only call attention when an answer is expected.
        answerLabel.isHidden = !(listening || awaiting)

        if listening {
            let transcript = session.partialTranscript
            answerLabel.text = transcript.isEmpty ? L10n.activeCallListening.current : transcript
            micButton.configuration?.baseBackgroundColor = .systemRed
            micButton.configuration?.baseForegroundColor = .white
            startMicPulse()
        } else if awaiting {
            answerLabel.text = L10n.activeCallTapToAnswer.current
            micButton.configuration?.baseBackgroundColor = Theme.accent
            micButton.configuration?.baseForegroundColor = .white
            startMicPulse()
        } else {
            micButton.configuration?.baseBackgroundColor = Theme.cardBackground
            micButton.configuration?.baseForegroundColor = Theme.accent
            stopMicPulse()
        }
    }

    private func startMicPulse() {
        guard micButton.layer.animation(forKey: "pulse") == nil else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.12
        pulse.duration = 0.7
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        micButton.layer.add(pulse, forKey: "pulse")
    }

    private func stopMicPulse() {
        micButton.layer.removeAnimation(forKey: "pulse")
    }

    // MARK: - Actions

    @objc private func didTapMute() { session.toggleMute() }
    @objc private func didTapSpeaker() { session.toggleSpeaker() }
    @objc private func didTapHangUp() { session.hangUp() }
    @objc private func didTapMinimize() { onMinimize?() }
    @objc private func didTapMic() { session.startListening() }
}
