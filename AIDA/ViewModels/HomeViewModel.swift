import Foundation

protocol HomeViewModelDelegate: AnyObject {
    func homeViewModel(_ viewModel: HomeViewModel, didSelect mission: Mission)
}

final class HomeViewModel {
    weak var delegate: HomeViewModelDelegate?

    let title = "Scegli la tua missione"
    let missions: [Mission] = Mission.placeholders

    func selectMission(at index: Int) {
        guard missions.indices.contains(index) else { return }
        delegate?.homeViewModel(self, didSelect: missions[index])
    }
}
