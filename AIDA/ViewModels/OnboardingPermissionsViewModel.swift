import Foundation

protocol OnboardingPermissionsViewModelDelegate: AnyObject {
    func onboardingDidComplete(_ viewModel: OnboardingPermissionsViewModel)
}

final class OnboardingPermissionsViewModel {
    weak var delegate: OnboardingPermissionsViewModelDelegate?

    let title = "Configura la tua avventura"
    let mission: Mission
    let permissions: [Permission] = Permission.all

    private var grantedStates: [Permission.Kind: Bool]

    init(mission: Mission) {
        self.mission = mission
        var initial: [Permission.Kind: Bool] = [:]
        for permission in Permission.all {
            initial[permission.kind] = permission.isMandatory
        }
        self.grantedStates = initial
    }

    func isGranted(_ kind: Permission.Kind) -> Bool {
        grantedStates[kind] ?? false
    }

    func setGranted(_ granted: Bool, for kind: Permission.Kind) {
        guard let permission = permissions.first(where: { $0.kind == kind }) else { return }
        if permission.isMandatory { return }
        grantedStates[kind] = granted
    }

    func confirm() {
        delegate?.onboardingDidComplete(self)
    }
}
