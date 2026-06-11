import UIKit

/// End-of-mission report: key moments and points earned, with a button to
/// collect the points and return to the main screen.
final class MissionReportViewController: UIViewController {
    private let viewModel: MissionReportViewModel
    var onCollect: (() -> Void)?

    private let collectButton = UIButton(type: .system)

    init(viewModel: MissionReportViewModel) {
        self.viewModel = viewModel
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
    }

    private func setupViews() {
        let badge = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
        badge.tintColor = .systemGreen
        badge.contentMode = .scaleAspectFit
        badge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 64)
        badge.setContentHuggingPriority(.required, for: .vertical)

        let titleLabel = UILabel()
        titleLabel.text = viewModel.screenTitle
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = viewModel.subtitle
        subtitleLabel.font = .systemFont(ofSize: 17)
        subtitleLabel.textColor = Theme.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let summaryCard = makeSummaryCard()
        let pointsCard = makePointsCard()

        let contentStack = UIStackView(arrangedSubviews: [badge, titleLabel, subtitleLabel, summaryCard, pointsCard])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16
        contentStack.setCustomSpacing(8, after: titleLabel)
        contentStack.setCustomSpacing(28, after: subtitleLabel)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        var collectConfig = UIButton.Configuration.filled()
        collectConfig.title = viewModel.collectButtonTitle
        collectConfig.baseBackgroundColor = .systemGreen
        collectConfig.cornerStyle = .large
        collectConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        collectButton.configuration = collectConfig
        collectButton.translatesAutoresizingMaskIntoConstraints = false
        collectButton.addTarget(self, action: #selector(didTapCollect), for: .touchUpInside)
        view.addSubview(collectButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: collectButton.topAnchor, constant: -16),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 32),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            collectButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            collectButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            collectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func makeSummaryCard() -> UIView {
        let header = UILabel()
        header.text = viewModel.summaryHeader
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        header.textColor = Theme.secondaryText

        let rows = viewModel.summaryPoints.map { point -> UIStackView in
            let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            check.tintColor = .systemGreen
            check.contentMode = .scaleAspectFit
            check.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18)
            check.setContentHuggingPriority(.required, for: .horizontal)

            let label = UILabel()
            label.text = point
            label.font = .systemFont(ofSize: 16)
            label.textColor = Theme.primaryText
            label.numberOfLines = 0

            let row = UIStackView(arrangedSubviews: [check, label])
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 10
            return row
        }

        let stack = UIStackView(arrangedSubviews: [header] + rows)
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = Theme.cardBackground
        card.layer.cornerRadius = Theme.cardCornerRadius
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        return card
    }

    private func makePointsCard() -> UIView {
        let pointsLabel = UILabel()
        pointsLabel.text = viewModel.pointsText
        pointsLabel.font = .systemFont(ofSize: 56, weight: .heavy)
        pointsLabel.textColor = Theme.accent
        pointsLabel.textAlignment = .center

        let caption = UILabel()
        caption.text = viewModel.pointsLabel
        caption.font = .systemFont(ofSize: 15, weight: .medium)
        caption.textColor = Theme.secondaryText
        caption.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [pointsLabel, caption])
        stack.axis = .vertical
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = Theme.cardBackground
        card.layer.cornerRadius = Theme.cardCornerRadius
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        return card
    }

    @objc private func didTapCollect() {
        onCollect?()
    }
}
