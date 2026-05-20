import Foundation

protocol BriefingViewModelDelegate: AnyObject {
    func briefingDidConfirm(_ viewModel: BriefingViewModel)
}

final class BriefingViewModel {
    weak var delegate: BriefingViewModelDelegate?

    let mission: Mission
    let briefingText: String
    private let speechService: SpeechService

    init(mission: Mission, speechService: SpeechService) {
        self.mission = mission
        self.speechService = speechService
        self.briefingText = """
        Benvenuto, agente.
        La città cambia volto al tramonto, e oggi avremo bisogno di te per esplorare un quartiere segnato da strane coincidenze. Le tue tappe ti porteranno tra strade poco battute, dove ogni indizio è parte di una storia più grande. Resta in ascolto, segui le indicazioni e prendi nota di tutto ciò che ti sembra fuori posto. L'avventura comincia adesso.
        """
    }

    func readBriefingAloud() {
        speechService.speak(briefingText)
    }

    func confirmReady() {
        speechService.stop()
        delegate?.briefingDidConfirm(self)
    }
}
