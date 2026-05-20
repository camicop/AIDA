import UIKit

final class BriefingViewController: UIViewController {
    private let viewModel: BriefingViewModel
    private let textView = UITextView()
    private let speakButton = UIButton(type: .system)
    private let readyButton = UIButton(type: .system)

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
        title = "Briefing"
        setupViews()
    }

    private func setupViews() {
        textView.text = viewModel.briefingText
        textView.font = .systemFont(ofSize: 17)
        textView.isEditable = false
        textView.backgroundColor = Theme.cardBackground
        textView.layer.cornerRadius = Theme.cardCornerRadius
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false

        var speakConfig = UIButton.Configuration.tinted()
        speakConfig.title = "Ascolta il briefing"
        speakConfig.image = UIImage(systemName: "speaker.wave.2.fill")
        speakConfig.imagePadding = 8
        speakConfig.cornerStyle = .large
        speakButton.configuration = speakConfig
        speakButton.addTarget(self, action: #selector(didTapSpeak), for: .touchUpInside)
        speakButton.translatesAutoresizingMaskIntoConstraints = false

        var readyConfig = UIButton.Configuration.filled()
        readyConfig.title = "Ho capito, sono pronto"
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
            textView.bottomAnchor.constraint(equalTo: speakButton.topAnchor, constant: -Theme.padding),

            speakButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            speakButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            speakButton.bottomAnchor.constraint(equalTo: readyButton.topAnchor, constant: -12),

            readyButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            readyButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            readyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.padding)
        ])
    }

    @objc private func didTapSpeak() {
        viewModel.readBriefingAloud()
    }

    @objc private func didTapReady() {
        viewModel.confirmReady()
    }
}
