import UIKit

final class SetupViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case age
        case duration
        case enigmas
        case zone
    }

    private let viewModel: SetupViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let startButton = UIButton(type: .system)

    init(viewModel: SetupViewModel) {
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
        updateStartButton()
        enableDeveloperModeAccess()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SessionRecorder.shared.stopRecording()
    }

    private func setupViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(dismissTap)
        tableView.register(AgeFieldCell.self, forCellReuseIdentifier: AgeFieldCell.reuseID)
        tableView.register(ToggleCell.self, forCellReuseIdentifier: ToggleCell.reuseID)
        tableView.register(DurationSliderCell.self, forCellReuseIdentifier: DurationSliderCell.reuseID)
        tableView.register(ZoneActionCell.self, forCellReuseIdentifier: ZoneActionCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        var config = UIButton.Configuration.filled()
        config.title = viewModel.startButtonTitle
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

    private func updateStartButton() {
        startButton.isEnabled = viewModel.canStart
    }

    @objc private func didTapStart() {
        view.endEditing(true)
        viewModel.confirmStart()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func ageRows() -> [AgeRow] {
        if viewModel.groupModeEnabled {
            return [.groupToggle, .minAge, .maxAge]
        } else {
            return [.singleAge, .groupToggle]
        }
    }

    private enum AgeRow {
        case singleAge
        case groupToggle
        case minAge
        case maxAge
    }
}

extension SetupViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .age: return ageRows().count
        case .duration, .enigmas, .zone: return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .age: return viewModel.ageSectionTitle
        case .duration: return viewModel.durationSectionTitle
        case .enigmas: return viewModel.enigmasSectionTitle
        case .zone: return viewModel.zoneSectionTitle
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .enigmas: return viewModel.photoEnigmasFooter
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .age:
            return ageCell(at: indexPath)
        case .duration:
            let cell = tableView.dequeueReusableCell(withIdentifier: DurationSliderCell.reuseID, for: indexPath) as! DurationSliderCell
            cell.configure(
                minutes: viewModel.durationMinutes,
                minValue: Float(viewModel.durationMin),
                maxValue: Float(viewModel.durationMax),
                durationLabel: viewModel.durationDisplay
            ) { [weak self, weak cell] value in
                guard let self else { return }
                self.viewModel.setDuration(fromSliderValue: value)
                cell?.updateLabel(self.viewModel.durationDisplay)
            }
            return cell
        case .enigmas:
            let cell = tableView.dequeueReusableCell(withIdentifier: ToggleCell.reuseID, for: indexPath) as! ToggleCell
            cell.configure(title: viewModel.photoEnigmasLabel, isOn: viewModel.photoEnigmasEnabled) { [weak self] isOn in
                self?.viewModel.setPhotoEnigmasEnabled(isOn)
            }
            return cell
        case .zone:
            let cell = tableView.dequeueReusableCell(withIdentifier: ZoneActionCell.reuseID, for: indexPath) as! ZoneActionCell
            cell.configure(title: viewModel.chooseZoneLabel, selectedZoneName: viewModel.selectedAreaDisplay)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .zone {
            view.endEditing(true)
            viewModel.didTapChooseZone()
        }
    }

    private func ageCell(at indexPath: IndexPath) -> UITableViewCell {
        let row = ageRows()[indexPath.row]
        switch row {
        case .singleAge:
            let cell = tableView.dequeueReusableCell(withIdentifier: AgeFieldCell.reuseID, for: indexPath) as! AgeFieldCell
            cell.configure(title: viewModel.singleAgePlaceholder, value: viewModel.singleAge) { [weak self] text in
                self?.viewModel.setSingleAge(text)
            }
            return cell
        case .groupToggle:
            let cell = tableView.dequeueReusableCell(withIdentifier: ToggleCell.reuseID, for: indexPath) as! ToggleCell
            cell.configure(title: viewModel.groupModeLabel, isOn: viewModel.groupModeEnabled) { [weak self] isOn in
                self?.viewModel.setGroupModeEnabled(isOn)
            }
            return cell
        case .minAge:
            let cell = tableView.dequeueReusableCell(withIdentifier: AgeFieldCell.reuseID, for: indexPath) as! AgeFieldCell
            cell.configure(title: viewModel.minAgePlaceholder, value: viewModel.minAge) { [weak self] text in
                self?.viewModel.setMinAge(text)
            }
            return cell
        case .maxAge:
            let cell = tableView.dequeueReusableCell(withIdentifier: AgeFieldCell.reuseID, for: indexPath) as! AgeFieldCell
            cell.configure(title: viewModel.maxAgePlaceholder, value: viewModel.maxAge) { [weak self] text in
                self?.viewModel.setMaxAge(text)
            }
            return cell
        }
    }
}

extension SetupViewController: SetupViewModelBinding {
    func setupViewModelDidUpdateAgeSection(_ viewModel: SetupViewModel) {
        view.endEditing(true)
        tableView.reloadSections(IndexSet(integer: Section.age.rawValue), with: .automatic)
    }

    func setupViewModelDidUpdateZoneSection(_ viewModel: SetupViewModel) {
        tableView.reloadSections(IndexSet(integer: Section.zone.rawValue), with: .automatic)
    }

    func setupViewModelDidUpdatePhotoEnigmasSection(_ viewModel: SetupViewModel) {
        tableView.reloadSections(IndexSet(integer: Section.enigmas.rawValue), with: .none)
    }

    func setupViewModelDidUpdateStartAvailability(_ viewModel: SetupViewModel) {
        updateStartButton()
    }

    func setupViewModel(_ viewModel: SetupViewModel, didDenyCameraWith title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.mapOpenSettings.current, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: L10n.mapCancel.current, style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - Cells

private final class AgeFieldCell: UITableViewCell {
    static let reuseID = "AgeFieldCell"

    private let titleLabel = UILabel()
    private let field = UITextField()
    private var onChange: ((String?) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none

        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        field.keyboardType = .numberPad
        field.font = .systemFont(ofSize: 17)
        field.borderStyle = .roundedRect
        field.textAlignment = .center
        field.placeholder = L10n.setupAgeFieldHint.current
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.setContentCompressionResistancePriority(.required, for: .horizontal)
        field.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        field.inputAccessoryView = makeDoneToolbar()

        contentView.addSubview(titleLabel)
        contentView.addSubview(field)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: field.leadingAnchor, constant: -12),

            field.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            field.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])
    }

    private func makeDoneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: L10n.keyboardDone.current, style: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [spacer, done]
        return toolbar
    }

    func configure(title: String, value: Int?, onChange: @escaping (String?) -> Void) {
        titleLabel.text = title
        field.text = value.map { String($0) } ?? ""
        self.onChange = onChange
    }

    @objc private func editingChanged() {
        onChange?(field.text)
    }

    @objc private func dismissKeyboard() {
        field.resignFirstResponder()
    }
}

private final class ToggleCell: UITableViewCell {
    static let reuseID = "ToggleCell"

    private let titleLabel = UILabel()
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
        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        contentView.addSubview(titleLabel)
        contentView.addSubview(toggle)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        titleLabel.text = title
        toggle.setOn(isOn, animated: false)
        self.onChange = onChange
    }

    @objc private func toggleChanged() {
        onChange?(toggle.isOn)
    }
}

private final class DurationSliderCell: UITableViewCell {
    static let reuseID = "DurationSliderCell"

    private let slider = UISlider()
    private let label = UILabel()
    private var onChange: ((Float) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = Theme.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [slider, label])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(minutes: Int, minValue: Float, maxValue: Float, durationLabel: String, onChange: @escaping (Float) -> Void) {
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.setValue(Float(minutes), animated: false)
        label.text = durationLabel
        self.onChange = onChange
    }

    func updateLabel(_ text: String) {
        label.text = text
    }

    @objc private func sliderChanged() {
        onChange?(slider.value)
    }
}

private final class ZoneActionCell: UITableViewCell {
    static let reuseID = "ZoneActionCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        accessoryType = .disclosureIndicator
        titleLabel.font = .systemFont(ofSize: 17)
        detailLabel.font = .systemFont(ofSize: 15)
        detailLabel.textColor = Theme.secondaryText
        detailLabel.textAlignment = .right
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(title: String, selectedZoneName: String?) {
        if let selectedZoneName {
            titleLabel.text = title
            detailLabel.text = selectedZoneName
            detailLabel.textColor = Theme.accent
        } else {
            titleLabel.text = title
            detailLabel.text = nil
        }
    }
}
