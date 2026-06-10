import Foundation
import AVFoundation

@MainActor
protocol CallSessionDelegate: AnyObject {
    func callSessionDidTick(_ session: CallSession)
    func callSessionDidChangeSpeaking(_ session: CallSession)
    func callSessionDidChangeControls(_ session: CallSession)
    /// Awaiting-answer / listening / partial-transcript state changed.
    func callSessionDidChangeInteraction(_ session: CallSession)
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

    /// The agent has asked something and is waiting for the user's answer.
    private(set) var isAwaitingAnswer = false
    /// The microphone is actively recognizing the user's speech.
    private(set) var isListening = false
    /// Live partial transcript shown while listening.
    private(set) var partialTranscript = ""

    private let chatViewModel: ChatViewModel
    private var messageSource: AgentMessageSource
    private let speech = SpeechService()
    private let recognizer = SpeechRecognitionService()

    /// Lines revealed while muted, spoken once the user unmutes (order preserved).
    private var mutedBacklog: [String] = []
    private var timerTask: Task<Void, Never>?

    init(chatViewModel: ChatViewModel, messageSource: AgentMessageSource) {
        self.chatViewModel = chatViewModel
        self.messageSource = messageSource
        super.init()
        self.messageSource.delegate = self
        speech.delegate = self
        recognizer.delegate = self
    }

    // MARK: - Lifecycle

    func start() {
        SpeechRecognitionService.requestAuthorization()
        activateAudioSession()
        startTimer()
        messageSource.start()
    }

    func hangUp() {
        guard !hasEnded else { return }
        hasEnded = true
        recognizer.cancel()
        messageSource.stop()
        speech.flushQueue()
        stopTimer()
        deactivateAudioSession()
        delegate?.callSessionDidEnd(self)
    }

    // MARK: - Answering

    /// Begins listening for the user to speak (tap-to-talk), available any time
    /// during the call. Stops the agent's voice first so it doesn't talk over
    /// the user. If the agent was awaiting an answer, the result drives the
    /// script; otherwise it's just sent as a chat message.
    func startListening() {
        guard !isListening, !hasEnded else { return }
        speech.flushQueue()
        isListening = true
        partialTranscript = ""
        delegate?.callSessionDidChangeInteraction(self)
        let locale = Locale(identifier: LocalizationManager.shared.currentLanguage.bcp47)
        recognizer.startListening(locale: locale)
    }

    /// Submits a typed answer (fallback when speech is unavailable). The chat
    /// bubble was already added by the chat input, so it isn't added again here.
    func submitTypedAnswer(_ text: String) {
        guard isAwaitingAnswer else { return }
        deliverAnswer(text, addBubble: false)
    }

    private func deliverAnswer(_ text: String, addBubble: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isAwaitingAnswer = false
        isListening = false
        partialTranscript = ""
        delegate?.callSessionDidChangeInteraction(self)
        if addBubble, !trimmed.isEmpty {
            chatViewModel.appendUserMessage(trimmed)
        }
        messageSource.submitUserResponse(trimmed)
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
            // earpiece; the earpiece is its default output (no .defaultToSpeaker),
            // and overrideOutputAudioPort switches to the loudspeaker.
            // Use .default mode, NOT .voiceChat: voiceChat's voice-processing I/O
            // plays at the quiet "call" volume; .default plays at media volume to
            // match the briefing, and switches routes cleanly.
            try session.setCategory(.playAndRecord, mode: .default, options: [])
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

    func messageSourceDidRequestUserResponse(_ source: AgentMessageSource) {
        isAwaitingAnswer = true
        delegate?.callSessionDidChangeInteraction(self)
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

extension CallSession: SpeechRecognitionServiceDelegate {
    func speechRecognition(_ service: SpeechRecognitionService, didProducePartial text: String) {
        partialTranscript = text
        delegate?.callSessionDidChangeInteraction(self)
    }

    func speechRecognition(_ service: SpeechRecognitionService, didFinishWith text: String) {
        deliverAnswer(text, addBubble: true)
    }

    func speechRecognitionDidFail(_ service: SpeechRecognitionService) {
        // Stay awaiting so the user can tap to retry, or type the answer.
        isListening = false
        partialTranscript = ""
        delegate?.callSessionDidChangeInteraction(self)
    }
}
