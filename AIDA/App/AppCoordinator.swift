import UIKit

final class AppCoordinator {
    private let navigationController: UINavigationController

    private weak var pendingSetupViewModel: SetupViewModel?

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
        let setupVM = SetupViewModel(mission: mission)
        setupVM.delegate = self
        let vc = SetupViewController(viewModel: setupVM)
        navigationController.pushViewController(vc, animated: true)
    }
}

extension AppCoordinator: SetupViewModelDelegate {
    func setupViewModelDidRequestZoneSelection(_ viewModel: SetupViewModel) {
        pendingSetupViewModel = viewModel
        let mapVM = MapViewModel(initialArea: viewModel.selectedArea)
        mapVM.delegate = self
        let mapVC = MapViewController(viewModel: mapVM)
        let nav = UINavigationController(rootViewController: mapVC)
        nav.modalPresentationStyle = .fullScreen
        navigationController.present(nav, animated: true)
    }

    func setupViewModel(_ viewModel: SetupViewModel, didConfirm configuration: MissionConfiguration) {
        SessionRecorder.shared.startRecording()
        SessionRecorder.shared.logEvent("MISSION_START")
        let briefingVM = BriefingViewModel(mission: viewModel.mission)
        briefingVM.delegate = self
        let vc = BriefingViewController(viewModel: briefingVM)
        navigationController.pushViewController(vc, animated: true)
    }
}

extension AppCoordinator: MapViewModelDelegate {
    func mapViewModel(_ viewModel: MapViewModel, didConfirm area: MissionArea) {
        navigationController.dismiss(animated: true) { [weak self] in
            self?.pendingSetupViewModel?.setSelectedArea(area)
        }
    }

    func mapViewModelDidCancel(_ viewModel: MapViewModel) {
        navigationController.dismiss(animated: true)
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

    func callDidRequestTestNavigation(_ viewModel: CallViewModel) {
        let audioVM = AudioNavigationViewModel()
        let vc = AudioNavigationViewController(viewModel: audioVM)
        navigationController.pushViewController(vc, animated: true)
    }
}
