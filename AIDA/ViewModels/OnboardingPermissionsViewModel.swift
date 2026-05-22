import Foundation

protocol OnboardingPermissionsViewModelDelegate: AnyObject {
    func onboardingDidComplete(_ viewModel: OnboardingPermissionsViewModel)
}

protocol OnboardingPermissionsViewModelBinding: AnyObject {
    func onboardingViewModel(_ viewModel: OnboardingPermissionsViewModel,
                              didUpdateGrantedFor kind: Permission.Kind,
                              granted: Bool)
}

final class OnboardingPermissionsViewModel {
    weak var delegate: OnboardingPermissionsViewModelDelegate?
    weak var binding: OnboardingPermissionsViewModelBinding?

    var title: String { L10n.onboardingTitle.current }
    var startButtonTitle: String { L10n.onboardingStart.current }
    var mandatoryTag: String { L10n.onboardingMandatoryTag.current }

    let mission: Mission
    var permissions: [Permission] { Permission.localizedAll }

    var canStart: Bool {
        grantedStates[.gps] ?? false
    }

    private var grantedStates: [Permission.Kind: Bool] = [:]
    private let permissionsService = PermissionsService()

    init(mission: Mission) {
        self.mission = mission
    }

    func isGranted(_ kind: Permission.Kind) -> Bool {
        grantedStates[kind] ?? false
    }

    func didToggle(kind: Permission.Kind, isOn: Bool) {
        if isOn {
            requestPermission(for: kind)
        } else {
            grantedStates[kind] = false
            binding?.onboardingViewModel(self, didUpdateGrantedFor: kind, granted: false)
        }
    }

    func confirm() {
        guard canStart else { return }
        delegate?.onboardingDidComplete(self)
    }

    private func requestPermission(for kind: Permission.Kind) {
        let handler: (Bool) -> Void = { [weak self] granted in
            guard let self else { return }
            self.grantedStates[kind] = granted
            self.binding?.onboardingViewModel(self, didUpdateGrantedFor: kind, granted: granted)
        }
        switch kind {
        case .gps:
            permissionsService.requestLocation(completion: handler)
        case .microphone:
            permissionsService.requestMicrophone(completion: handler)
        case .camera:
            permissionsService.requestCamera(completion: handler)
        case .healthKit:
            permissionsService.requestHealthKit(completion: handler)
        }
    }
}
