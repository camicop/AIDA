import UIKit

final class OnboardingPermissionsViewController: UIViewController {
    private let viewModel: OnboardingPermissionsViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let startButton = UIButton(type: .system)

    init(viewModel: OnboardingPermissionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = viewModel.title
        setupViews()
    }

    private func setupViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PermissionToggleCell.self, forCellReuseIdentifier: PermissionToggleCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        var config = UIButton.Configuration.filled()
        config.title = "Inizia"
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        startButton.configuration = config
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
        view.addSubview(startButton)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -Theme.padding),

            startButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            startButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.padding)
        ])
    }

    @objc private func didTapStart() {
        viewModel.confirm()
    }
}

extension OnboardingPermissionsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.permissions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PermissionToggleCell.reuseID, for: indexPath) as! PermissionToggleCell
        let permission = viewModel.permissions[indexPath.row]
        cell.configure(with: permission,
                       isOn: viewModel.isGranted(permission.kind)) { [weak self] isOn in
            self?.viewModel.setGranted(isOn, for: permission.kind)
        }
        return cell
    }
}

private final class PermissionToggleCell: UITableViewCell {
    static let reuseID = "PermissionToggleCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let toggle = UISwitch()
    private var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.accent
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 0
        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = Theme.secondaryText
        descriptionLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        contentView.addSubview(iconView)
        contentView.addSubview(textStack)
        contentView.addSubview(toggle)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            textStack.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with permission: Permission, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        iconView.image = UIImage(systemName: permission.iconName)
        let mandatoryTag = permission.isMandatory ? "  •  obbligatorio" : ""
        titleLabel.text = permission.title + mandatoryTag
        descriptionLabel.text = permission.description
        toggle.isOn = isOn
        toggle.isEnabled = !permission.isMandatory
        self.onChange = onChange
    }

    @objc private func toggleChanged() {
        onChange?(toggle.isOn)
    }
}
