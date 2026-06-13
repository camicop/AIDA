import UIKit

final class BriefingViewController: UIViewController {
    private let viewModel: BriefingViewModel
    private let textView = UITextView(usingTextLayoutManager: false)
    private let speakButton = UIButton(type: .system)
    private let readyButton = UIButton(type: .system)

    private let baseFont = UIFont.systemFont(ofSize: 17)

    init(viewModel: BriefingViewModel) {
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
        viewModel.binding = self
        setupViews()
        setupGestures()
        renderAttributedText()
        updateSpeakButton()
        enableDeveloperModeAccess()
    }

    private func setupViews() {
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = Theme.cardBackground
        textView.layer.cornerRadius = Theme.cardCornerRadius
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false

        speakButton.configuration = makeSpeakConfiguration()
        speakButton.addTarget(self, action: #selector(didTapSpeak), for: .touchUpInside)
        speakButton.translatesAutoresizingMaskIntoConstraints = false

        var readyConfig = UIButton.Configuration.filled()
        readyConfig.title = viewModel.readyButtonTitle
        readyConfig.cornerStyle = .large
        readyConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        readyButton.configuration = readyConfig
        readyButton.addTarget(self, action: #selector(didTapReady), for: .touchUpInside)
        readyButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(textView)
        view.addSubview(speakButton)
        view.addSubview(readyButton)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.padding),
            textView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            textView.bottomAnchor.constraint(lessThanOrEqualTo: speakButton.topAnchor, constant: -Theme.padding),

            speakButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            speakButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            speakButton.bottomAnchor.constraint(equalTo: readyButton.topAnchor, constant: -12),

            readyButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            readyButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            readyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.padding)
        ])
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTextTap(_:)))
        textView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTextPan(_:)))
        pan.maximumNumberOfTouches = 1
        textView.addGestureRecognizer(pan)
    }

    private func renderAttributedText() {
        let nsText = viewModel.briefingText as NSString
        let attributed = NSMutableAttributedString(string: nsText as String, attributes: [
            .font: baseFont,
            .foregroundColor: Theme.primaryText
        ])
        let location = max(0, min(viewModel.spokenLocation, nsText.length))
        if location > 0 {
            attributed.addAttribute(.foregroundColor,
                                    value: Theme.accent,
                                    range: NSRange(location: 0, length: location))
        }
        textView.attributedText = attributed
    }

    private func updateSpeakButton() {
        speakButton.configuration = makeSpeakConfiguration()
    }

    private func makeSpeakConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.tinted()
        config.cornerStyle = .large
        config.imagePadding = 8
        config.title = viewModel.playButtonTitle
        config.image = UIImage(systemName: viewModel.playButtonIconName)
        return config
    }

    private func characterIndex(at point: CGPoint) -> Int {
        let localPoint = CGPoint(
            x: point.x - textView.textContainerInset.left,
            y: point.y - textView.textContainerInset.top
        )
        return textView.layoutManager.characterIndex(
            for: localPoint,
            in: textView.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
    }

    @objc private func didTapSpeak() {
        viewModel.togglePlayback()
    }

    @objc private func didTapReady() {
        viewModel.confirmReady()
    }

    @objc private func handleTextTap(_ recognizer: UITapGestureRecognizer) {
        let index = characterIndex(at: recognizer.location(in: textView))
        viewModel.seek(toCharacterIndex: index)
    }

    @objc private func handleTextPan(_ recognizer: UIPanGestureRecognizer) {
        let index = characterIndex(at: recognizer.location(in: textView))
        switch recognizer.state {
        case .changed:
            viewModel.previewSpokenLocation(at: index)
        case .ended, .cancelled, .failed:
            viewModel.seek(toCharacterIndex: index)
        default:
            break
        }
    }
}

extension BriefingViewController: BriefingViewModelBinding {
    func briefingViewModelDidChangePlaybackState(_ viewModel: BriefingViewModel) {
        updateSpeakButton()
    }

    func briefingViewModel(_ viewModel: BriefingViewModel, didUpdateSpokenLocation location: Int) {
        renderAttributedText()
    }
}
