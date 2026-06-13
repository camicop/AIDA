import UIKit

final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    /// When set, replaces the system back button with a custom one that runs
    /// this handler instead of popping (used to confirm abandoning the mission).
    var onBack: (() -> Void)?
    /// Tapped on the green banner (return to a running call) or the top-right
    /// button (call again after the call has ended).
    var onReturnToCall: (() -> Void)?
    /// Tapped on the "I've arrived" checkpoint card.
    var onCheckpoint: (() -> Void)?
    /// Tapped on the "take a photo" card.
    var onCamera: (() -> Void)?
    /// Tapped on the "start navigation" card.
    var onNavigate: (() -> Void)?
    /// Tapped on the "finalize the mission" card.
    var onFinalize: (() -> Void)?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let callBanner = UIButton(type: .system)
    private let checkpointButton = UIButton(type: .system)
    private let cameraButton = UIButton(type: .system)
    private let navButton = UIButton(type: .system)
    private let finalizeButton = UIButton(type: .system)
    private var callBannerHeight: NSLayoutConstraint!
    private var checkpointHeight: NSLayoutConstraint!
    private var cameraHeight: NSLayoutConstraint!
    private var navHeight: NSLayoutConstraint!
    private var finalizeHeight: NSLayoutConstraint!
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

    /// Purple "I've arrived" card above the input bar, shown at checkpoints.
    func setCheckpointVisible(_ visible: Bool) {
        guard checkpointButton.isHidden == visible else { return }
        checkpointButton.isHidden = !visible
        checkpointHeight.constant = visible ? 52 : 0
        view.layoutIfNeeded()
    }

    @objc private func didTapCheckpoint() {
        setCheckpointVisible(false)
        onCheckpoint?()
    }

    /// Accent "take a photo" card above the input bar, shown for photo enigmas.
    func setCameraVisible(_ visible: Bool) {
        guard cameraButton.isHidden == visible else { return }
        cameraButton.isHidden = !visible
        cameraHeight.constant = visible ? 52 : 0
        view.layoutIfNeeded()
    }

    @objc private func didTapCamera() {
        setCameraVisible(false)
        onCamera?()
    }

    /// Accent "start navigation" card above the input bar, shown for the proximity step.
    func setNavigationVisible(_ visible: Bool) {
        guard navButton.isHidden == visible else { return }
        navButton.isHidden = !visible
        navHeight.constant = visible ? 52 : 0
        view.layoutIfNeeded()
    }

    @objc private func didTapNavigate() {
        setNavigationVisible(false)
        onNavigate?()
    }

    /// Green "finalize the mission" card above the input bar, shown at the end.
    func setFinalizeVisible(_ visible: Bool) {
        guard finalizeButton.isHidden == visible else { return }
        finalizeButton.isHidden = !visible
        finalizeHeight.constant = visible ? 52 : 0
        view.layoutIfNeeded()
    }

    @objc private func didTapFinalize() {
        setFinalizeVisible(false)
        onFinalize?()
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
        tableView.register(ChatImageCell.self, forCellReuseIdentifier: ChatImageCell.reuseID)
        tableView.register(ChatHintsCell.self, forCellReuseIdentifier: ChatHintsCell.reuseID)
        tableView.register(ChatSuccessCell.self, forCellReuseIdentifier: ChatSuccessCell.reuseID)
        tableView.register(ChatLoadingCell.self, forCellReuseIdentifier: ChatLoadingCell.reuseID)
        tableView.register(ChatTypingCell.self, forCellReuseIdentifier: ChatTypingCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        var checkpointConfig = UIButton.Configuration.filled()
        checkpointConfig.title = L10n.checkpointArrivedButton.current
        checkpointConfig.baseBackgroundColor = .systemPurple
        checkpointConfig.baseForegroundColor = .white
        checkpointConfig.image = UIImage(systemName: "mappin.and.ellipse")
        checkpointConfig.imagePadding = 8
        checkpointConfig.cornerStyle = .fixed
        checkpointButton.configuration = checkpointConfig
        checkpointButton.isHidden = true
        checkpointButton.translatesAutoresizingMaskIntoConstraints = false
        checkpointButton.addTarget(self, action: #selector(didTapCheckpoint), for: .touchUpInside)
        view.addSubview(checkpointButton)

        var cameraConfig = UIButton.Configuration.filled()
        cameraConfig.title = L10n.cameraButtonTitle.current
        cameraConfig.baseBackgroundColor = Theme.accent
        cameraConfig.baseForegroundColor = .white
        cameraConfig.image = UIImage(systemName: "camera.fill")
        cameraConfig.imagePadding = 8
        cameraConfig.cornerStyle = .fixed
        cameraButton.configuration = cameraConfig
        cameraButton.isHidden = true
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.addTarget(self, action: #selector(didTapCamera), for: .touchUpInside)
        view.addSubview(cameraButton)

        var navConfig = UIButton.Configuration.filled()
        navConfig.title = L10n.navigationButtonTitle.current
        navConfig.baseBackgroundColor = Theme.accent
        navConfig.baseForegroundColor = .white
        navConfig.image = UIImage(systemName: "location.north.line.fill")
        navConfig.imagePadding = 8
        navConfig.cornerStyle = .fixed
        navButton.configuration = navConfig
        navButton.isHidden = true
        navButton.translatesAutoresizingMaskIntoConstraints = false
        navButton.addTarget(self, action: #selector(didTapNavigate), for: .touchUpInside)
        view.addSubview(navButton)

        var finalizeConfig = UIButton.Configuration.filled()
        finalizeConfig.title = L10n.finalizeButtonTitle.current
        finalizeConfig.baseBackgroundColor = .systemGreen
        finalizeConfig.baseForegroundColor = .white
        finalizeConfig.image = UIImage(systemName: "checkmark.seal.fill")
        finalizeConfig.imagePadding = 8
        finalizeConfig.cornerStyle = .fixed
        finalizeButton.configuration = finalizeConfig
        finalizeButton.isHidden = true
        finalizeButton.translatesAutoresizingMaskIntoConstraints = false
        finalizeButton.addTarget(self, action: #selector(didTapFinalize), for: .touchUpInside)
        view.addSubview(finalizeButton)

        inputContainer.backgroundColor = Theme.cardBackground
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainer)

        textField.placeholder = viewModel.inputPlaceholder
        textField.borderStyle = .roundedRect
        textField.returnKeyType = .send
        textField.delegate = self
        textField.inputAccessoryView = makeKeyboardToolbar()
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
        checkpointHeight = checkpointButton.heightAnchor.constraint(equalToConstant: 0)
        cameraHeight = cameraButton.heightAnchor.constraint(equalToConstant: 0)
        navHeight = navButton.heightAnchor.constraint(equalToConstant: 0)
        finalizeHeight = finalizeButton.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            callBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            callBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            callBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            callBannerHeight,

            tableView.topAnchor.constraint(equalTo: callBanner.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: checkpointButton.topAnchor),

            checkpointButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            checkpointButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            checkpointButton.bottomAnchor.constraint(equalTo: cameraButton.topAnchor),
            checkpointHeight,

            cameraButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraButton.bottomAnchor.constraint(equalTo: navButton.topAnchor),
            cameraHeight,

            navButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navButton.bottomAnchor.constraint(equalTo: finalizeButton.topAnchor),
            navHeight,

            finalizeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            finalizeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            finalizeButton.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),
            finalizeHeight,

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

    private func makeKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(
            title: L10n.keyboardDone.current,
            style: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )
        toolbar.items = [spacer, done]
        return toolbar
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
        let message = viewModel.messages[indexPath.row]
        switch message.kind {
        case .text(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.reuseID, for: indexPath) as! ChatMessageCell
            cell.configure(text: text, sender: message.sender)
            return cell
        case .image(let image):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatImageCell.reuseID, for: indexPath) as! ChatImageCell
            cell.configure(image: image, sender: message.sender)
            return cell
        case .hints(let group):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatHintsCell.reuseID, for: indexPath) as! ChatHintsCell
            cell.configure(with: group)
            return cell
        case .success(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatSuccessCell.reuseID, for: indexPath) as! ChatSuccessCell
            cell.configure(text: text)
            return cell
        case .loading(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatLoadingCell.reuseID, for: indexPath) as! ChatLoadingCell
            cell.configure(text: text)
            return cell
        case .typing:
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatTypingCell.reuseID, for: indexPath) as! ChatTypingCell
            cell.startAnimating()
            return cell
        }
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

    func configure(text: String, sender: ChatMessage.Sender) {
        messageLabel.text = text
        switch sender {
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

/// Bubble holding an image — a mission map (agent, left) or a sent photo
/// (user, right).
private final class ChatImageCell: UITableViewCell {
    static let reuseID = "ChatImageCell"

    private let imageWidth: CGFloat = 240
    private let maxImageHeight: CGFloat = 360

    private let bubbleView = UIView()
    private let pictureView = UIImageView()
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var aspectConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        bubbleView.backgroundColor = Theme.cardBackground
        bubbleView.layer.cornerRadius = 16
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        // Aspect-fit so the whole image shows (no cropping).
        pictureView.contentMode = .scaleAspectFit
        pictureView.clipsToBounds = true
        pictureView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(pictureView)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        aspectConstraint = pictureView.heightAnchor.constraint(equalToConstant: imageWidth * 9.0 / 16.0)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            pictureView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            pictureView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            pictureView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            pictureView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            pictureView.widthAnchor.constraint(equalToConstant: imageWidth),
            aspectConstraint
        ])
    }

    func configure(image: UIImage, sender: ChatMessage.Sender) {
        pictureView.image = image
        // Size the bubble to the image's aspect ratio (capped), so it isn't cropped.
        let ratio = image.size.width > 0 ? image.size.height / image.size.width : 9.0 / 16.0
        aspectConstraint.constant = min(imageWidth * ratio, maxImageHeight)
        switch sender {
        case .user:
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        case .agent:
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
    }
}

/// Green agent bubble with a checkmark — a positive result (e.g. analysis done).
private final class ChatSuccessCell: UITableViewCell {
    static let reuseID = "ChatSuccessCell"

    private let bubbleView = UIView()
    private let iconView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        bubbleView.backgroundColor = .systemGreen
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(iconView)

        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        messageLabel.textColor = .white
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),

            iconView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }

    func configure(text: String) {
        messageLabel.text = text
    }
}

/// Transient agent bubble with a spinner and a label (e.g. "Validating clue…").
private final class ChatLoadingCell: UITableViewCell {
    static let reuseID = "ChatLoadingCell"

    private let bubbleView = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        bubbleView.backgroundColor = Theme.cardBackground
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        spinner.startAnimating()
        spinner.setContentHuggingPriority(.required, for: .horizontal)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(spinner)

        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = Theme.primaryText
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),

            spinner.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            spinner.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }

    func configure(text: String) {
        messageLabel.text = text
        spinner.startAnimating()
    }
}

/// Transient agent bubble with three animated "typing…" dots.
private final class ChatTypingCell: UITableViewCell {
    static let reuseID = "ChatTypingCell"

    private let bubbleView = UIView()
    private let dots = [UIView(), UIView(), UIView()]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        bubbleView.backgroundColor = Theme.cardBackground
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(stack)

        for dot in dots {
            dot.backgroundColor = Theme.secondaryText
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            stack.addArrangedSubview(dot)
        }

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),

            stack.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14)
        ])
    }

    func startAnimating() {
        for (index, dot) in dots.enumerated() {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.3
            animation.toValue = 1.0
            animation.duration = 0.6
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.2
            dot.layer.add(animation, forKey: "typing")
        }
    }
}

/// Agent bubble holding tappable hint cards.
private final class ChatHintsCell: UITableViewCell {
    static let reuseID = "ChatHintsCell"

    private let stack = UIStackView()
    private var group: HintOptionGroup?
    private var optionButtons: [UIButton] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }

    func configure(with group: HintOptionGroup) {
        self.group = group
        optionButtons.forEach { $0.removeFromSuperview() }
        optionButtons.removeAll()

        for (index, option) in group.options.enumerated() {
            var config = UIButton.Configuration.tinted()
            config.title = option.title
            config.baseBackgroundColor = Theme.accent
            config.baseForegroundColor = Theme.accent
            config.cornerStyle = .large
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            let button = UIButton(configuration: config)
            button.contentHorizontalAlignment = .center
            button.tag = index
            button.addTarget(self, action: #selector(didTapOption(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(button)
            optionButtons.append(button)
        }
    }

    @objc private func didTapOption(_ sender: UIButton) {
        group?.onSelect?(sender.tag)
    }
}
