import Foundation
import AVFoundation

@MainActor
protocol CallSessionDelegate: AnyObject {
    func callSessionDidTick(_ session: CallSession)
    func callSessionDidChangeSpeaking(_ session: CallSession)
    func callSessionDidChangeControls(_ session: CallSession)
    func callSessionDidEnd(_ session: CallSession)
}

/// Owns the lifetime and state of a simulated call: drives the (swappable)
/// message source, mirrors each revealed line into the chat and the TTS queue,
/// manages the audio session/route, and runs the call timer. The session
/// outlives both the full-screen and minimized UIs, so minimizing or restoring
/// never interrupts the call.
@MainActor
final class CallSession: NSObject {
    weak var delegate: CallSessionDelegate?

    let agentName = L10n.appName.current
    let agentIconName = "waveform.circle.fill"

    private(set) var isMuted = false
    private(set) var isSpeaker = false
    private(set) var isSpeaking = false
    private(set) var hasStartedTalking = false
    private(set) var hasEnded = false
    private(set) var durationSeconds = 0

    private let chatViewModel: ChatViewModel
    private var messageSource: AgentMessageSource
    private let speech = SpeechService()

    /// Lines revealed while muted, spoken once the user unmutes (order preserved).
    private var mutedBacklog: [String] = []
    private var timerTask: Task<Void, Never>?

    init(chatViewModel: ChatViewModel, messageSource: AgentMessageSource) {
        self.chatViewModel = chatViewModel
        self.messageSource = messageSource
        super.init()
        self.messageSource.delegate = self
        speech.delegate = self
    }

    // MARK: - Lifecycle

    func start() {
        activateAudioSession()
        startTimer()
        messageSource.start()
    }

    func hangUp() {
        guard !hasEnded else { return }
        hasEnded = true
        messageSource.stop()
        speech.flushQueue()
        stopTimer()
        deactivateAudioSession()
        delegate?.callSessionDidEnd(self)
    }

    // MARK: - Controls

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            speech.pause()
        } else {
            speech.resume()
            for text in mutedBacklog { speech.enqueue(text) }
            mutedBacklog.removeAll()
        }
        delegate?.callSessionDidChangeControls(self)
    }

    func toggleSpeaker() {
        isSpeaker.toggle()
        applyAudioRoute()
        delegate?.callSessionDidChangeControls(self)
    }

    // MARK: - Display

    var durationText: String {
        String(format: "%02d:%02d", durationSeconds / 60, durationSeconds % 60)
    }

    var statusText: String {
        if isSpeaking { return L10n.activeCallStatusSpeaking.current }
        if !hasStartedTalking { return L10n.activeCallStatusConnecting.current }
        return L10n.activeCallStatusListening.current
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.durationSeconds += 1
                self.delegate?.callSessionDidTick(self)
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Audio session

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord is the only category that allows routing to the
            // earpiece; .voiceChat with no .defaultToSpeaker keeps the earpiece
            // as the default output, like a real phone call.
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [])
            try session.setActive(true)
            applyAudioRoute()
        } catch {
            print("CallSession: audio session activation failed — \(error)")
        }
    }

    private func applyAudioRoute() {
        let session = AVAudioSession.sharedInstance()
        try? session.overrideOutputAudioPort(isSpeaker ? .speaker : .none)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

extension CallSession: AgentMessageSourceDelegate {
    func messageSource(_ source: AgentMessageSource, didReveal text: String) {
        hasStartedTalking = true
        chatViewModel.appendAgentMessage(text)
        if isMuted {
            mutedBacklog.append(text)
        } else {
            speech.enqueue(text)
        }
    }

    func messageSourceDidFinish(_ source: AgentMessageSource) {}
}

extension CallSession: SpeechServiceDelegate {
    func speechService(_ service: SpeechService, didChangeState state: SpeechService.State) {
        let speaking = (state == .speaking)
        guard speaking != isSpeaking else { return }
        isSpeaking = speaking
        delegate?.callSessionDidChangeSpeaking(self)
    }
}
