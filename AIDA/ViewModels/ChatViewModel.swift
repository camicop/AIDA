import Foundation

protocol ChatViewModelDelegate: AnyObject {
    func chatViewModelDidUpdateMessages(_ viewModel: ChatViewModel)
}

final class ChatViewModel {
    weak var delegate: ChatViewModelDelegate?

    var screenTitle: String { L10n.chatTitle.current }
    var inputPlaceholder: String { L10n.chatPlaceholder.current }

    private let agentReplyText: String

    /// When set, typed user messages are offered here first. If it returns true
    /// the message was consumed (e.g. as a call answer) and no canned reply runs.
    var userMessageInterceptor: ((String) -> Bool)?

    private(set) var messages: [ChatMessage]

    init() {
        self.messages = [
            ChatMessage(sender: .agent, text: L10n.chatAgentGreeting.current)
        ]
        self.agentReplyText = L10n.chatAgentReply.current
    }

    /// Appends an agent message originating from the call layer (scripted or live)
    /// so it appears as a chat bubble in sync with the spoken voice.
    func appendAgentMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(sender: .agent, text: trimmed))
        delegate?.chatViewModelDidUpdateMessages(self)
    }

    /// Appends a user message originating from the call layer (e.g. a spoken
    /// answer transcribed to text), without triggering the canned reply.
    func appendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(sender: .user, text: trimmed))
        delegate?.chatViewModelDidUpdateMessages(self)
    }

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(sender: .user, text: trimmed))
        delegate?.chatViewModelDidUpdateMessages(self)

        // Let the call layer claim this as an answer before falling back to the
        // canned reply.
        if userMessageInterceptor?(trimmed) == true { return }

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }
            self.messages.append(ChatMessage(sender: .agent, text: self.agentReplyText))
            self.delegate?.chatViewModelDidUpdateMessages(self)
        }
    }
}
