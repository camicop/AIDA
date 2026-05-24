import UIKit

final class CallViewController: UIViewController {
    private let viewModel: CallViewModel
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let answerButton = UIButton(type: .system)
    private let chatButton = UIButton(type: .system)
    private let testButton = UIButton(type: .system)

    init(viewModel: CallViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationItem.hidesBackButton = true
        setupViews()
    }

    private func setupViews() {
        avatarView.image = UIImage(systemName: viewModel.agentIconName)
        avatarView.tintColor = Theme.accent
        avatarView.contentMode = .scaleAspectFit
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.text = viewModel.agentName
        nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
        nameLabel.textAlignment = .center

        subtitleLabel.text = viewModel.agentSubtitle
        subtitleLabel.font = .systemFont(ofSize: 17)
        subtitleLabel.textColor = Theme.secondaryText
        subtitleLabel.textAlignment = .center

        let headerStack = UIStackView(arrangedSubviews: [avatarView, nameLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 12
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        var answerConfig = UIButton.Configuration.filled()
        answerConfig.title = viewModel.answerButtonTitle
        answerConfig.image = UIImage(systemName: "phone.fill")
        answerConfig.imagePadding = 8
        answerConfig.baseBackgroundColor = .systemGreen
        answerConfig.cornerStyle = .large
        answerConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        answerButton.configuration = answerConfig
        answerButton.addTarget(self, action: #selector(didTapAnswer), for: .touchUpInside)

        var chatConfig = UIButton.Configuration.tinted()
        chatConfig.title = viewModel.chatButtonTitle
        chatConfig.image = UIImage(systemName: "bubble.left.and.bubble.right.fill")
        chatConfig.imagePadding = 8
        chatConfig.cornerStyle = .large
        chatConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        chatButton.configuration = chatConfig
        chatButton.addTarget(self, action: #selector(didTapChat), for: .touchUpInside)

        var testConfig = UIButton.Configuration.gray()
        testConfig.title = viewModel.testButtonTitle
        testConfig.image = UIImage(systemName: "location.fill.viewfinder")
        testConfig.imagePadding = 8
        testConfig.cornerStyle = .large
        testConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        testButton.configuration = testConfig
        testButton.addTarget(self, action: #selector(didTapTest), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [answerButton, chatButton, testButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerStack)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 120),
            avatarView.heightAnchor.constraint(equalToConstant: 120),

            headerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            headerStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            headerStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),

            buttonStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.padding)
        ])
    }

    @objc private func didTapAnswer() {
        viewModel.answer()
    }

    @objc private func didTapChat() {
        viewModel.preferChat()
    }

    @objc private func didTapTest() {
        viewModel.tapTest()
    }
}
