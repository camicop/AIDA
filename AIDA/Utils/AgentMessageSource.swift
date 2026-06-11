import Foundation

/// Produces an agent-driven mission, pausing for the user where needed. The
/// scripted implementation runs a fixed list of steps; a future implementation
/// can drive the same callbacks from a live API without the call layer noticing.
@MainActor
protocol AgentMessageSource: AnyObject {
    var delegate: AgentMessageSourceDelegate? { get set }
    func start()
    func stop()
    /// Feeds the user's typed/spoken answer back to a source awaiting one.
    func submitUserResponse(_ text: String)
    /// Resolves a non-text interactive step (checkpoint reached, photo taken,
    /// proximity target found, hint selected).
    func signalInteractionComplete()
}

@MainActor
protocol AgentMessageSourceDelegate: AnyObject {
    func messageSource(_ source: AgentMessageSource, didReveal text: String)
    /// The agent is "typing" a message that is about to be revealed.
    func messageSourceDidStartTyping(_ source: AgentMessageSource)
    /// Show a transient spinner row with `text` (e.g. "Validating clue…").
    func messageSource(_ source: AgentMessageSource, didStartLoading text: String)
    /// Reveal a green success bubble (with a checkmark) saying `text`.
    func messageSource(_ source: AgentMessageSource, didRevealSuccess text: String)
    /// The agent asked something and is now waiting for the user to answer.
    func messageSourceDidRequestUserResponse(_ source: AgentMessageSource)
    /// Show a map snapshot (target `distanceMeters` along `bearingDegrees`).
    func messageSource(_ source: AgentMessageSource, didRequestMapBearing bearingDegrees: Double, distanceMeters: Double)
    /// Show the "I've arrived" checkpoint affordance; log `event` when reached.
    func messageSource(_ source: AgentMessageSource, didRequestCheckpoint event: String)
    /// Present the fake camera screen.
    func messageSourceDidRequestCamera(_ source: AgentMessageSource)
    /// Present the proximity navigation screen; log `event` when found.
    func messageSource(_ source: AgentMessageSource, didRequestProximity event: String)
    /// Show the inline hint cards.
    func messageSourceDidRequestHints(_ source: AgentMessageSource)
    /// The mission completed; log `event`.
    func messageSource(_ source: AgentMessageSource, didComplete event: String)
    /// Show the "finalize the mission" button.
    func messageSourceDidRequestFinalize(_ source: AgentMessageSource)
    func messageSourceDidFinish(_ source: AgentMessageSource)
}

/// A single beat of a scripted mission.
enum AgentScriptStep {
    case say(String)
    /// Like `say`, but with a short delay (a quick follow-up line).
    case sayQuick(String)
    /// Map snapshot inserted as an agent bubble.
    case map(bearingDegrees: Double, distanceMeters: Double)
    /// Wait for the "I've arrived" button; `event` is logged on tap.
    case checkpoint(event: String)
    /// Present the fake camera (the captured photo is shown as a user bubble).
    case camera
    /// Show a transient spinner row with `text` for `seconds`.
    case loading(text: String, seconds: Double)
    /// Reveal a green success bubble (with a checkmark).
    case success(String)
    /// Present proximity navigation, log `event` on success, then say `confirmation`.
    case proximity(event: String, confirmation: String)
    /// Ask `question` and wait. `accept` ends it; otherwise `retry` is said and it
    /// re-asks. When `help` matches (e.g. "I don't know"): if `helpOffer` is set,
    /// the agent first asks whether to spend points for sources and only shows
    /// hints if `helpOfferAccept` matches; if `helpOffer` is nil, hints are shown
    /// directly. Either way it then waits for the answer again.
    case ask(question: String,
             retry: String,
             accept: (String) -> Bool,
             help: (String) -> Bool,
             helpOffer: String?,
             helpOfferAccept: ((String) -> Bool)?)
    /// Log `event`; no UI change.
    case complete(event: String)
    /// Show the "finalize the mission" button as the final beat.
    case finalize
}

/// Runs an ordered list of steps, revealing lines with a delay and pausing on
/// interactive steps until the call layer signals completion.
@MainActor
final class ScriptedAgentMessageSource: AgentMessageSource {
    weak var delegate: AgentMessageSourceDelegate?

    private let steps: [AgentScriptStep]
    private let firstDelay: TimeInterval
    private let interMessageDelay: TimeInterval
    private let postAnswerDelay: TimeInterval
    /// How long the "typing…" dots show before a message appears.
    private let typingLeadTime: TimeInterval = 1.8

    private var task: Task<Void, Never>?
    private var pendingContinuation: CheckedContinuation<String, Never>?
    private var didRevealAnything = false
    /// Set after a user action so the agent replies promptly, not after the full
    /// inter-message delay.
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
        pendingContinuation?.resume(returning: "")
        pendingContinuation = nil
    }

    func submitUserResponse(_ text: String) {
        resume(text)
    }

    func signalInteractionComplete() {
        resume("")
    }

    private func resume(_ value: String) {
        let continuation = pendingContinuation
        pendingContinuation = nil
        continuation?.resume(returning: value)
    }

    private func run() async {
        for step in steps {
            if Task.isCancelled { return }
            switch step {
            case .say(let text):
                await revealAgentText(text)

            case .sayQuick(let text):
                justAnswered = true
                await revealAgentText(text)

            case .map(let bearing, let distance):
                await pauseWithTyping()
                if Task.isCancelled { return }
                didRevealAnything = true
                delegate?.messageSource(self, didRequestMapBearing: bearing, distanceMeters: distance)

            case .checkpoint(let event):
                delegate?.messageSource(self, didRequestCheckpoint: event)
                _ = await awaitSignal()
                if Task.isCancelled { return }
                justAnswered = true

            case .camera:
                delegate?.messageSourceDidRequestCamera(self)
                _ = await awaitSignal()
                if Task.isCancelled { return }
                justAnswered = true

            case .loading(let text, let seconds):
                delegate?.messageSource(self, didStartLoading: text)
                try? await Task.sleep(for: .seconds(seconds))

            case .success(let text):
                if Task.isCancelled { return }
                didRevealAnything = true
                delegate?.messageSource(self, didRevealSuccess: text)

            case .proximity(let event, let confirmation):
                delegate?.messageSource(self, didRequestProximity: event)
                _ = await awaitSignal()
                if Task.isCancelled { return }
                justAnswered = true
                await revealAgentText(confirmation)

            case let .ask(question, retry, accept, help, helpOffer, helpOfferAccept):
                await revealAgentText(question)
                while true {
                    let answer = await awaitUserResponse()
                    if Task.isCancelled { return }
                    if accept(answer) {
                        justAnswered = true
                        break
                    }
                    if help(answer) {
                        await runHelp(offer: helpOffer, offerAccept: helpOfferAccept)
                        if Task.isCancelled { return }
                        continue
                    }
                    justAnswered = true
                    await revealAgentText(retry)
                }

            case .complete(let event):
                delegate?.messageSource(self, didComplete: event)

            case .finalize:
                delegate?.messageSourceDidRequestFinalize(self)
            }
        }
        if !Task.isCancelled {
            delegate?.messageSourceDidFinish(self)
        }
    }

    /// Handles a "help" answer: optionally offers to spend points for sources,
    /// then shows the answer-choice cards. The cards submit one of the choices as
    /// the answer, which the surrounding ask loop then evaluates.
    private func runHelp(offer: String?, offerAccept: ((String) -> Bool)?) async {
        if let offer {
            justAnswered = true
            await revealAgentText(offer)
            if Task.isCancelled { return }
            let response = await awaitUserResponse()
            if Task.isCancelled { return }
            guard offerAccept?(response) ?? false else { return }
        }
        delegate?.messageSourceDidRequestHints(self)
    }

    /// Waits (with a "typing…" indicator near the end), then reveals the text.
    private func revealAgentText(_ text: String) async {
        await pauseWithTyping()
        if Task.isCancelled { return }
        reveal(text)
    }

    private func pauseWithTyping() async {
        let total = nextDelay()
        let lead = min(total, typingLeadTime)
        let silent = max(0, total - lead)
        if silent > 0 {
            try? await Task.sleep(for: .seconds(silent))
            if Task.isCancelled { return }
        }
        delegate?.messageSourceDidStartTyping(self)
        try? await Task.sleep(for: .seconds(lead))
    }

    private func nextDelay() -> TimeInterval {
        if !didRevealAnything {
            return firstDelay
        }
        if justAnswered {
            justAnswered = false
            return postAnswerDelay
        }
        return interMessageDelay
    }

    private func reveal(_ text: String) {
        didRevealAnything = true
        delegate?.messageSource(self, didReveal: text)
    }

    private func awaitUserResponse() async -> String {
        delegate?.messageSourceDidRequestUserResponse(self)
        return await awaitSignal()
    }

    private func awaitSignal() async -> String {
        await withCheckedContinuation { continuation in
            self.pendingContinuation = continuation
        }
    }
}
