import UIKit

final class HomeViewController: UIViewController {
    private let viewModel: HomeViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let titleLabel = UILabel()
    private let languageButton = UIButton(type: .system)

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupViews()
        applyLocalizedContent()
        enableDeveloperModeAccess()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SessionRecorder.shared.stopRecording()
    }

    private func setupViews() {
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "globe")
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        languageButton.configuration = config
        languageButton.setContentHuggingPriority(.required, for: .horizontal)
        languageButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        languageButton.addTarget(self, action: #selector(didTapLanguageButton), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, languageButton])
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(StoryCardCell.self, forCellReuseIdentifier: StoryCardCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.padding),
            headerStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: Theme.padding),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyLocalizedContent() {
        title = viewModel.navTitle
        titleLabel.text = viewModel.title
        languageButton.configuration?.title = viewModel.currentLanguage.displayName
        tableView.reloadData()
    }

    @objc private func didTapLanguageButton() {
        let next: Language = viewModel.currentLanguage == .italian ? .english : .italian
        viewModel.currentLanguage = next
        applyLocalizedContent()
    }
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.missions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StoryCardCell.reuseID, for: indexPath) as! StoryCardCell
        cell.configure(with: viewModel.missions[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.selectMission(at: indexPath.row)
    }
}

private final class StoryCardCell: UITableViewCell {
    static let reuseID = "StoryCardCell"

    private let card = GradientCardView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let durationLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.numberOfLines = 2

        durationLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        durationLabel.textColor = UIColor.white.withAlphaComponent(0.9)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, durationLabel])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.setCustomSpacing(10, after: subtitleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(iconView)
        card.addSubview(textStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            textStack.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
    }

    func configure(with mission: Mission) {
        iconView.image = UIImage(systemName: mission.iconName)
        titleLabel.text = mission.title.current
        subtitleLabel.text = mission.subtitle.current
        durationLabel.text = mission.estimatedDuration.current
        card.apply(top: mission.accentTop, bottom: mission.accentBottom)
    }
}

private final class GradientCardView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func apply(top: UIColor, bottom: UIColor) {
        gradientLayer.colors = [top.cgColor, bottom.cgColor]
    }
}
