import UIKit

final class AppCoordinator {
    private let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let viewModel = HomeViewModel()
        viewModel.delegate = self
        let viewController = HomeViewController(viewModel: viewModel)
        navigationController.setViewControllers([viewController], animated: false)
    }
}

extension AppCoordinator: HomeViewModelDelegate {
    func homeViewModel(_ viewModel: HomeViewModel, didSelect mission: Mission) {
        let onboardingVM = OnboardingPermissionsViewModel(mission: mission)
        onboardingVM.delegate = self
        let vc = OnboardingPermissionsViewController(viewModel: onboardingVM)
        navigationController.pushViewController(vc, animated: true)
    }
}

extension AppCoordinator: OnboardingPermissionsViewModelDelegate {
    func onboardingDidComplete(_ viewModel: OnboardingPermissionsViewModel) {
        let briefingVM = BriefingViewModel(mission: viewModel.mission)
        briefingVM.delegate = self
        let vc = BriefingViewController(viewModel: briefingVM)
        navigationController.pushViewController(vc, animated: true)
    }
}

extension AppCoordinator: BriefingViewModelDelegate {
    func briefingDidConfirm(_ viewModel: BriefingViewModel) {
        let callVM = CallViewModel()
        callVM.delegate = self
        let vc = CallViewController(viewModel: callVM)
        navigationController.pushViewController(vc, animated: true)
    }
}

extension AppCoordinator: CallViewModelDelegate {
    func callDidAnswer(_ viewModel: CallViewModel) {
        let audioVM = AudioNavigationViewModel()
        let vc = AudioNavigationViewController(viewModel: audioVM)
        navigationController.pushViewController(vc, animated: true)
    }

    func callDidPreferChat(_ viewModel: CallViewModel) {
        let chatVM = ChatViewModel()
        let vc = ChatViewController(viewModel: chatVM)
        navigationController.pushViewController(vc, animated: true)
    }
}
