import Foundation

protocol CallViewModelDelegate: AnyObject {
    func callDidAnswer(_ viewModel: CallViewModel)
    func callDidPreferChat(_ viewModel: CallViewModel)
}

final class CallViewModel {
    weak var delegate: CallViewModelDelegate?

    var agentName: String { L10n.appName.current }
    var agentSubtitle: String { L10n.callIncoming.current }
    let agentIconName = "waveform.circle.fill"

    var answerButtonTitle: String { L10n.callAnswer.current }
    var chatButtonTitle: String { L10n.callPreferChat.current }

    func answer() {
        delegate?.callDidAnswer(self)
    }

    func preferChat() {
        delegate?.callDidPreferChat(self)
    }
}
