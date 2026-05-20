import Foundation

protocol ChatViewModelDelegate: AnyObject {
    func chatViewModelDidUpdateMessages(_ viewModel: ChatViewModel)
}

final class ChatViewModel {
    weak var delegate: ChatViewModelDelegate?

    private(set) var messages: [ChatMessage] = [
        ChatMessage(sender: .agent, text: "Ciao, agente. Sono A.I.D.A. Sei pronto a partire?")
    ]

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(sender: .user, text: trimmed))
        delegate?.chatViewModelDidUpdateMessages(self)

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }
            self.messages.append(ChatMessage(sender: .agent, text: "Ricevuto. Resta in attesa di istruzioni…"))
            self.delegate?.chatViewModelDidUpdateMessages(self)
        }
    }
}
