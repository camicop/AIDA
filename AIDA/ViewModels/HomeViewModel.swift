import Foundation

protocol HomeViewModelDelegate: AnyObject {
    func homeViewModel(_ viewModel: HomeViewModel, didSelect mission: Mission)
}

final class HomeViewModel {
    weak var delegate: HomeViewModelDelegate?

    var navTitle: String { L10n.appName.current }
    var title: String { L10n.homeTitle.current }
    var missions: [Mission] { Mission.localizedPlaceholders }

    var currentLanguage: Language {
        get { LocalizationManager.shared.currentLanguage }
        set { LocalizationManager.shared.currentLanguage = newValue }
    }

    func selectMission(at index: Int) {
        let list = missions
        guard list.indices.contains(index) else { return }
        delegate?.homeViewModel(self, didSelect: list[index])
    }
}
