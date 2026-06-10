import Foundation

/// Produces agent messages one at a time. The scripted implementation reveals a
/// fixed list with a delay between entries; a future implementation can stream
/// the same callbacks from a live API without the call layer noticing.
@MainActor
protocol AgentMessageSource: AnyObject {
    var delegate: AgentMessageSourceDelegate? { get set }
    func start()
    func stop()
}

@MainActor
protocol AgentMessageSourceDelegate: AnyObject {
    func messageSource(_ source: AgentMessageSource, didReveal text: String)
    func messageSourceDidFinish(_ source: AgentMessageSource)
}

/// Reveals an ordered list of strings, one at a time, with a configurable delay
/// before each line (simulating the agent talking on a call).
@MainActor
final class ScriptedAgentMessageSource: AgentMessageSource {
    weak var delegate: AgentMessageSourceDelegate?

    private let lines: [String]
    private let firstDelay: TimeInterval
    private let interMessageDelay: TimeInterval

    private var index = 0
    private var task: Task<Void, Never>?

    init(lines: [String],
         firstDelay: TimeInterval = 1.0,
         interMessageDelay: TimeInterval = 3.5) {
        self.lines = lines
        self.firstDelay = firstDelay
        self.interMessageDelay = interMessageDelay
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            var isFirst = true
            while !Task.isCancelled, self.index < self.lines.count {
                let delay = isFirst ? self.firstDelay : self.interMessageDelay
                try? await Task.sleep(for: .seconds(delay))
                if Task.isCancelled { return }
                let line = self.lines[self.index]
                self.index += 1
                isFirst = false
                self.delegate?.messageSource(self, didReveal: line)
            }
            if !Task.isCancelled {
                self.delegate?.messageSourceDidFinish(self)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
