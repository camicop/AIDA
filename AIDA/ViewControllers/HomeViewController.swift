import UIKit

final class HomeViewController: UIViewController {
    private let viewModel: HomeViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let titleLabel = UILabel()

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
        title = "A.I.D.A."
        setupViews()
    }

    private func setupViews() {
        titleLabel.text = viewModel.title
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MissionCardCell.self, forCellReuseIdentifier: MissionCardCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.padding),
            titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.padding),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.missions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MissionCardCell.reuseID, for: indexPath) as! MissionCardCell
        cell.configure(with: viewModel.missions[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.selectMission(at: indexPath.row)
    }
}

private final class MissionCardCell: UITableViewCell {
    static let reuseID = "MissionCardCell"

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
        accessoryType = .disclosureIndicator

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = Theme.secondaryText
        subtitleLabel.numberOfLines = 0
        durationLabel.font = .systemFont(ofSize: 12, weight: .medium)
        durationLabel.textColor = Theme.accent

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, durationLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with mission: Mission) {
        titleLabel.text = mission.title
        subtitleLabel.text = mission.subtitle
        durationLabel.text = "≈ \(mission.estimatedDuration)"
    }
}
