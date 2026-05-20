import Foundation

protocol CallViewModelDelegate: AnyObject {
    func callDidAnswer(_ viewModel: CallViewModel)
    func callDidPreferChat(_ viewModel: CallViewModel)
}

final class CallViewModel {
    weak var delegate: CallViewModelDelegate?

    let agentName = "A.I.D.A."
    let agentSubtitle = "Chiamata in arrivo…"
    let agentIconName = "waveform.circle.fill"

    func answer() {
        delegate?.callDidAnswer(self)
    }

    func preferChat() {
        delegate?.callDidPreferChat(self)
    }
}
