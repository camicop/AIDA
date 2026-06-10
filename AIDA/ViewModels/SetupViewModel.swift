import Foundation

protocol SetupViewModelDelegate: AnyObject {
    func setupViewModelDidRequestZoneSelection(_ viewModel: SetupViewModel)
    func setupViewModel(_ viewModel: SetupViewModel, didConfirm configuration: MissionConfiguration)
}

protocol SetupViewModelBinding: AnyObject {
    func setupViewModelDidUpdateAgeSection(_ viewModel: SetupViewModel)
    func setupViewModelDidUpdateZoneSection(_ viewModel: SetupViewModel)
    func setupViewModelDidUpdatePhotoEnigmasSection(_ viewModel: SetupViewModel)
    func setupViewModelDidUpdateStartAvailability(_ viewModel: SetupViewModel)
    func setupViewModel(_ viewModel: SetupViewModel, didDenyCameraWith title: String, message: String)
}

final class SetupViewModel {
    weak var delegate: SetupViewModelDelegate?
    weak var binding: SetupViewModelBinding?

    let mission: Mission

    let durationMin = 20
    let durationMax = 60
    let durationStep = 5

    private(set) var groupModeEnabled: Bool = false
    private(set) var singleAge: Int?
    private(set) var minAge: Int?
    private(set) var maxAge: Int?
    private(set) var durationMinutes: Int = 30
    private(set) var photoEnigmasEnabled: Bool = false
    private(set) var selectedArea: MissionArea?

    private let permissionsService = PermissionsService()

    init(mission: Mission) {
        self.mission = mission
    }

    // MARK: - Localized helpers

    var screenTitle: String { L10n.setupTitle.current }
    var startButtonTitle: String { L10n.setupStartMission.current }
    var ageSectionTitle: String { L10n.setupSectionAge.current }
    var durationSectionTitle: String { L10n.setupSectionDuration.current }
    var enigmasSectionTitle: String { L10n.setupSectionEnigmas.current }
    var zoneSectionTitle: String { L10n.setupSectionZone.current }
    var groupModeLabel: String { L10n.setupGroupMode.current }
    var singleAgePlaceholder: String { L10n.setupAgePlaceholder.current }
    var minAgePlaceholder: String { L10n.setupGroupMinAgePlaceholder.current }
    var maxAgePlaceholder: String { L10n.setupGroupMaxAgePlaceholder.current }
    var photoEnigmasLabel: String { L10n.setupPhotoEnigmas.current }
    var photoEnigmasFooter: String { L10n.setupPhotoEnigmasFooter.current }
    var chooseZoneLabel: String { L10n.setupChooseZone.current }

    var durationDisplay: String {
        String(format: L10n.setupDurationFormat.current, durationMinutes)
    }

    var selectedAreaDisplay: String? {
        selectedArea?.displayName.current
    }

    // MARK: - Derived state

    var ageMode: MissionConfiguration.AgeMode? {
        if groupModeEnabled {
            guard let lower = minAge, let upper = maxAge, lower > 0, upper >= lower else { return nil }
            return .group(min: lower, max: upper)
        } else {
            guard let value = singleAge, value > 0 else { return nil }
            return .single(age: value)
        }
    }

    var canStart: Bool {
        ageMode != nil && selectedArea != nil
    }

    // MARK: - Mutations

    func setGroupModeEnabled(_ enabled: Bool) {
        guard groupModeEnabled != enabled else { return }
        groupModeEnabled = enabled
        binding?.setupViewModelDidUpdateAgeSection(self)
        binding?.setupViewModelDidUpdateStartAvailability(self)
    }

    func setSingleAge(_ text: String?) {
        singleAge = parseAge(text)
        binding?.setupViewModelDidUpdateStartAvailability(self)
    }

    func setMinAge(_ text: String?) {
        minAge = parseAge(text)
        binding?.setupViewModelDidUpdateStartAvailability(self)
    }

    func setMaxAge(_ text: String?) {
        maxAge = parseAge(text)
        binding?.setupViewModelDidUpdateStartAvailability(self)
    }

    func setDuration(fromSliderValue value: Float) {
        let raw = Int(value.rounded())
        let stepped = (raw / durationStep) * durationStep
        durationMinutes = min(max(stepped, durationMin), durationMax)
    }

    func setPhotoEnigmasEnabled(_ enabled: Bool) {
        if !enabled {
            photoEnigmasEnabled = false
            binding?.setupViewModelDidUpdatePhotoEnigmasSection(self)
            return
        }
        permissionsService.requestCamera { [weak self] granted in
            guard let self else { return }
            if granted {
                self.photoEnigmasEnabled = true
            } else {
                self.photoEnigmasEnabled = false
                self.binding?.setupViewModel(
                    self,
                    didDenyCameraWith: L10n.setupCameraDeniedTitle.current,
                    message: L10n.setupCameraDeniedMessage.current
                )
            }
            self.binding?.setupViewModelDidUpdatePhotoEnigmasSection(self)
        }
    }

    func didTapChooseZone() {
        delegate?.setupViewModelDidRequestZoneSelection(self)
    }

    func setSelectedArea(_ area: MissionArea) {
        selectedArea = area
        binding?.setupViewModelDidUpdateZoneSection(self)
        binding?.setupViewModelDidUpdateStartAvailability(self)
    }

    func clearSelectedArea() {
        guard selectedArea != nil else { return }
        selectedArea = nil
        binding?.setupViewModelDidUpdateZoneSection(self)
        binding?.setupViewModelDidUpdateStartAvailability(self)
    }

    func confirmStart() {
        guard let mode = ageMode, let area = selectedArea else { return }
        let config = MissionConfiguration(
            ageMode: mode,
            durationMinutes: durationMinutes,
            photoEnigmasEnabled: photoEnigmasEnabled,
            area: area
        )
        delegate?.setupViewModel(self, didConfirm: config)
    }

    private func parseAge(_ text: String?) -> Int? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }
}
