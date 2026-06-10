import Foundation

/// Produces agent messages, possibly pausing to wait for the user's answer. The
/// scripted implementation runs a fixed list of steps; a future implementation
/// can drive the same callbacks from a live API without the call layer noticing.
@MainActor
protocol AgentMessageSource: AnyObject {
    var delegate: AgentMessageSourceDelegate? { get set }
    func start()
    func stop()
    /// Feeds the user's answer back to a source that is awaiting one.
    func submitUserResponse(_ text: String)
}

@MainActor
protocol AgentMessageSourceDelegate: AnyObject {
    func messageSource(_ source: AgentMessageSource, didReveal text: String)
    /// The agent has asked something and is now waiting for the user to answer.
    func messageSourceDidRequestUserResponse(_ source: AgentMessageSource)
    func messageSourceDidFinish(_ source: AgentMessageSource)
}

/// A single beat of a scripted conversation.
enum AgentScriptStep {
    /// The agent says a line.
    case say(String)
    /// The agent asks `question` and waits. While `accept` rejects the answer it
    /// re-asks with `retry`; once accepted it moves on.
    case ask(question: String, retry: String, accept: (String) -> Bool)
}

/// Runs an ordered list of steps, revealing lines with a delay and pausing on
/// `.ask` steps until `submitUserResponse` delivers an accepted answer.
@MainActor
final class ScriptedAgentMessageSource: AgentMessageSource {
    weak var delegate: AgentMessageSourceDelegate?

    private let steps: [AgentScriptStep]
    private let firstDelay: TimeInterval
    private let interMessageDelay: TimeInterval
    private let postAnswerDelay: TimeInterval

    private var task: Task<Void, Never>?
    private var responseContinuation: CheckedContinuation<String, Never>?
    private var didRevealAnything = false
    /// Set after an accepted answer so the agent replies promptly, not after the
    /// full inter-message delay.
    private var justAnswered = false

    init(steps: [AgentScriptStep],
         firstDelay: TimeInterval = 2.0,
         interMessageDelay: TimeInterval = 6.0,
         postAnswerDelay: TimeInterval = 1.0) {
        self.steps = steps
        self.firstDelay = firstDelay
        self.interMessageDelay = interMessageDelay
        self.postAnswerDelay = postAnswerDelay
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        // Unblock a pending await so the cancelled run loop can exit.
        responseContinuation?.resume(returning: "")
        responseContinuation = nil
    }

    func submitUserResponse(_ text: String) {
        let continuation = responseContinuation
        responseContinuation = nil
        continuation?.resume(returning: text)
    }

    private func run() async {
        for step in steps {
            if Task.isCancelled { return }
            switch step {
            case .say(let text):
                await pauseBeforeReveal()
                if Task.isCancelled { return }
                reveal(text)

            case .ask(let question, let retry, let accept):
                await pauseBeforeReveal()
                if Task.isCancelled { return }
                reveal(question)
                while true {
                    let answer = await awaitUserResponse()
                    if Task.isCancelled { return }
                    if accept(answer) {
                        justAnswered = true
                        break
                    }
                    reveal(retry)
                }
            }
        }
        if !Task.isCancelled {
            delegate?.messageSourceDidFinish(self)
        }
    }

    private func pauseBeforeReveal() async {
        let delay: TimeInterval
        if !didRevealAnything {
            delay = firstDelay
        } else if justAnswered {
            delay = postAnswerDelay
            justAnswered = false
        } else {
            delay = interMessageDelay
        }
        try? await Task.sleep(for: .seconds(delay))
    }

    private func reveal(_ text: String) {
        didRevealAnything = true
        delegate?.messageSource(self, didReveal: text)
    }

    private func awaitUserResponse() async -> String {
        delegate?.messageSourceDidRequestUserResponse(self)
        return await withCheckedContinuation { continuation in
            self.responseContinuation = continuation
        }
    }
}
