import UIKit

final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    /// When set, replaces the system back button with a custom one that runs
    /// this handler instead of popping (used to confirm abandoning the mission).
    var onBack: (() -> Void)?
    /// Tapped on the green banner (return to a running call) or the top-right
    /// button (call again after the call has ended).
    var onReturnToCall: (() -> Void)?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let callBanner = UIButton(type: .system)
    private var callBannerHeight: NSLayoutConstraint!
    private var inputBottomConstraint: NSLayoutConstraint!

    private lazy var returnCallButton = UIBarButtonItem(
        image: UIImage(systemName: "phone.fill"),
        style: .plain,
        target: self,
        action: #selector(didTapReturnToCall)
    )

    init(viewModel: ChatViewModel) {
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
        viewModel.delegate = self
        setupViews()
        observeKeyboard()
        enableDeveloperModeAccess()
        setupNavigationButtons()
    }

    private func setupNavigationButtons() {
        if onBack != nil {
            navigationItem.hidesBackButton = true
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(didTapBack)
            )
        }
        returnCallButton.accessibilityLabel = L10n.activeCallRecallBanner.current
    }

    @objc private func didTapBack() {
        onBack?()
    }

    @objc private func didTapReturnToCall() {
        onReturnToCall?()
    }

    // MARK: - Return-to-call affordances

    /// Green banner pinned to the top, shown while a call is minimized.
    func setCallBannerVisible(_ visible: Bool) {
        guard callBanner.isHidden == visible else { return }
        callBanner.isHidden = !visible
        callBannerHeight.constant = visible ? 44 : 0
        view.layoutIfNeeded()
    }

    func setCallBannerText(_ text: String) {
        var title = AttributedString(text)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.foregroundColor = .white
        callBanner.configuration?.attributedTitle = title
    }

    /// Small top-right button, shown only when not in a call (to call again).
    func setReturnButtonVisible(_ visible: Bool) {
        navigationItem.rightBarButtonItem = visible ? returnCallButton : nil
    }

    private func setupViews() {
        var bannerConfig = UIButton.Configuration.filled()
        bannerConfig.baseBackgroundColor = .systemGreen
        bannerConfig.baseForegroundColor = .white
        bannerConfig.image = UIImage(systemName: "phone.fill")
        bannerConfig.imagePadding = 8
        bannerConfig.cornerStyle = .fixed
        callBanner.configuration = bannerConfig
        callBanner.isHidden = true
        callBanner.translatesAutoresizingMaskIntoConstraints = false
        callBanner.addTarget(self, action: #selector(didTapReturnToCall), for: .touchUpInside)
        view.addSubview(callBanner)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.allowsSelection = false
        tableView.keyboardDismissMode = .interactive
        tableView.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        inputContainer.backgroundColor = Theme.cardBackground
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainer)

        textField.placeholder = viewModel.inputPlaceholder
        textField.borderStyle = .roundedRect
        textField.returnKeyType = .send
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false

        var sendConfig = UIButton.Configuration.filled()
        sendConfig.image = UIImage(systemName: "paperplane.fill")
        sendConfig.cornerStyle = .capsule
        sendButton.configuration = sendConfig
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        inputContainer.addSubview(textField)
        inputContainer.addSubview(sendButton)

        inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        callBannerHeight = callBanner.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            callBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            callBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            callBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            callBannerHeight,

            tableView.topAnchor.constraint(equalTo: callBanner.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottomConstraint,

            textField.leadingAnchor.constraint(equalTo: inputContainer.layoutMarginsGuide.leadingAnchor),
            textField.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            textField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.layoutMarginsGuide.trailingAnchor),
            sendButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self,
                                                selector: #selector(keyboardWillChangeFrame(_:)),
                                                name: UIResponder.keyboardWillChangeFrameNotification,
                                                object: nil)
        NotificationCenter.default.addObserver(self,
                                                selector: #selector(keyboardWillHide(_:)),
                                                name: UIResponder.keyboardWillHideNotification,
                                                object: nil)
    }

    @objc private func keyboardWillChangeFrame(_ note: Notification) {
        guard let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let endFrame = frameValue.cgRectValue
        let bottomInset = view.bounds.height - endFrame.origin.y
        inputBottomConstraint.constant = -max(0, bottomInset - view.safeAreaInsets.bottom)
        view.layoutIfNeeded()
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        inputBottomConstraint.constant = 0
        view.layoutIfNeeded()
    }

    @objc private func didTapSend() {
        let text = textField.text ?? ""
        textField.text = ""
        viewModel.sendUserMessage(text)
    }

    private func scrollToBottom() {
        let count = viewModel.messages.count
        guard count > 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: count - 1, section: 0), at: .bottom, animated: true)
    }
}

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.reuseID, for: indexPath) as! ChatMessageCell
        cell.configure(with: viewModel.messages[indexPath.row])
        return cell
    }
}

extension ChatViewController: UITableViewDelegate {}

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapSend()
        return true
    }
}

extension ChatViewController: ChatViewModelDelegate {
    func chatViewModelDidUpdateMessages(_ viewModel: ChatViewModel) {
        tableView.reloadData()
        scrollToBottom()
    }
}

private final class ChatMessageCell: UITableViewCell {
    static let reuseID = "ChatMessageCell"

    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }

    func configure(with message: ChatMessage) {
        messageLabel.text = message.text
        switch message.sender {
        case .user:
            bubbleView.backgroundColor = Theme.accent
            messageLabel.textColor = .white
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        case .agent:
            bubbleView.backgroundColor = Theme.cardBackground
            messageLabel.textColor = Theme.primaryText
            leadingConstraint.isActive = true
            trailingConstraint.isActive = false
        }
    }
}
