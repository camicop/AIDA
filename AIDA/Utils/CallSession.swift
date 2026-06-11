import UIKit
import AVFoundation
import CoreLocation

@MainActor
protocol CallSessionDelegate: AnyObject {
    func callSessionDidTick(_ session: CallSession)
    func callSessionDidChangeSpeaking(_ session: CallSession)
    func callSessionDidChangeControls(_ session: CallSession)
    /// Awaiting-answer / listening / partial-transcript state changed.
    func callSessionDidChangeInteraction(_ session: CallSession)
    /// The "I've arrived" checkpoint affordance should show/hide.
    func callSessionDidChangeCheckpoint(_ session: CallSession)
    /// The "take a photo" affordance should show/hide.
    func callSessionDidChangeCameraPrompt(_ session: CallSession)
    /// The "start navigation" affordance should show/hide.
    func callSessionDidChangeNavigationPrompt(_ session: CallSession)
    /// The "finalize the mission" affordance should show/hide.
    func callSessionDidChangeFinalizePrompt(_ session: CallSession)
    /// A mission element appeared in the chat; surface the chat if the full call
    /// screen is covering it.
    func callSessionNeedsChatVisible(_ session: CallSession)
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
    /// The agent is waiting for the user to tap "I've arrived" at a checkpoint.
    private(set) var isAwaitingCheckpoint = false
    /// The agent is waiting for the user to tap the "take a photo" button.
    private(set) var isAwaitingPhoto = false
    /// The agent is waiting for the user to tap the "start navigation" button.
    private(set) var isAwaitingNavigation = false
    /// The mission is over and waiting for the user to tap "finalize the mission".
    private(set) var isAwaitingFinalize = false

    private var pendingCheckpointEvent: String?
    private var pendingProximityEvent: String?
    private let mapFallback = CLLocationCoordinate2D(latitude: 46.0664, longitude: 11.1213)

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
        chatViewModel.setTyping(false)
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
        // Re-assert .playAndRecord in case a presented screen (e.g. proximity
        // navigation) switched the shared session to .playback.
        activateAudioSession()
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

    // MARK: - Mission interactions

    /// Called when the user taps the "I've arrived" checkpoint button.
    func checkpointReached() {
        guard isAwaitingCheckpoint else { return }
        isAwaitingCheckpoint = false
        if let event = pendingCheckpointEvent {
            SessionRecorder.shared.logEvent(event)
            pendingCheckpointEvent = nil
        }
        chatViewModel.appendUserMessage(L10n.checkpointArrivedMessage.current)
        delegate?.callSessionDidChangeCheckpoint(self)
        messageSource.signalInteractionComplete()
    }

    /// Called when the fake camera captures a photo. Shows it as a user-sent
    /// image bubble, then advances the script.
    func cameraCaptured() {
        isAwaitingPhoto = false
        delegate?.callSessionDidChangeCameraPrompt(self)
        chatViewModel.appendUserImage(Self.missionPhoto())
        messageSource.signalInteractionComplete()
    }

    /// The "photo" shown in the chat. Uses the "facade" asset if present;
    /// otherwise a placeholder is used.
    private static func missionPhoto() -> UIImage {
        if let asset = UIImage(named: "facade") { return asset }
        let size = CGSize(width: 240, height: 180)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemGray3.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let config = UIImage.SymbolConfiguration(pointSize: 48)
            if let symbol = UIImage(systemName: "photo.fill", withConfiguration: config)?
                .withTintColor(.systemGray, renderingMode: .alwaysOriginal) {
                symbol.draw(at: CGPoint(x: (size.width - symbol.size.width) / 2,
                                        y: (size.height - symbol.size.height) / 2))
            }
        }
    }

    /// Called when the proximity screen's "target found" button is tapped.
    func proximityFound() {
        isAwaitingNavigation = false
        delegate?.callSessionDidChangeNavigationPrompt(self)
        if let event = pendingProximityEvent {
            SessionRecorder.shared.logEvent(event)
            pendingProximityEvent = nil
        }
        // The proximity screen reconfigured/deactivated the shared audio session;
        // re-activate ours so the agent's voice works again.
        activateAudioSession()
        messageSource.signalInteractionComplete()
    }

    /// Presents three possible answers (years) as tappable cards. Tapping one
    /// submits it as the answer to the enigma.
    private func presentAnswerOptions() {
        let options = [
            HintOptionGroup.Option(title: "1715", value: "1715"),
            HintOptionGroup.Option(title: "1812", value: "1812"),
            HintOptionGroup.Option(title: "1230", value: "1230")
        ]
        let group = HintOptionGroup(options: options)
        group.onSelect = { [weak self] index in
            guard let self, index < options.count else { return }
            self.deliverAnswer(options[index].value, addBubble: true)
        }
        chatViewModel.appendHints(group)
    }

    private func renderMapBubble(bearingDegrees: Double, distanceMeters: Double) {
        let center = SessionRecorder.shared.currentLocation?.coordinate ?? mapFallback
        MapSnapshotRenderer.render(center: center,
                                   bearingDegrees: bearingDegrees,
                                   distanceMeters: distanceMeters) { [weak self] image in
            guard let self, let image else { return }
            self.chatViewModel.appendAgentImage(image)
        }
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
        speakAgentLine(text)
    }

    /// Speaks an agent line, queueing it for after unmute if currently muted.
    private func speakAgentLine(_ text: String) {
        if isMuted {
            mutedBacklog.append(text)
        } else {
            speech.enqueue(text)
        }
    }

    func messageSourceDidStartTyping(_ source: AgentMessageSource) {
        chatViewModel.setTyping(true)
    }

    func messageSource(_ source: AgentMessageSource, didStartLoading text: String) {
        chatViewModel.setLoading(text, on: true)
        speakAgentLine(text)
    }

    func messageSource(_ source: AgentMessageSource, didRevealSuccess text: String) {
        hasStartedTalking = true
        chatViewModel.appendSuccess(text)
        speakAgentLine(text)
    }

    func messageSourceDidRequestUserResponse(_ source: AgentMessageSource) {
        isAwaitingAnswer = true
        delegate?.callSessionDidChangeInteraction(self)
    }

    func messageSource(_ source: AgentMessageSource, didRequestMapBearing bearingDegrees: Double, distanceMeters: Double) {
        delegate?.callSessionNeedsChatVisible(self)
        renderMapBubble(bearingDegrees: bearingDegrees, distanceMeters: distanceMeters)
    }

    func messageSource(_ source: AgentMessageSource, didRequestCheckpoint event: String) {
        pendingCheckpointEvent = event
        isAwaitingCheckpoint = true
        delegate?.callSessionNeedsChatVisible(self)
        delegate?.callSessionDidChangeCheckpoint(self)
    }

    func messageSourceDidRequestCamera(_ source: AgentMessageSource) {
        isAwaitingPhoto = true
        delegate?.callSessionNeedsChatVisible(self)
        delegate?.callSessionDidChangeCameraPrompt(self)
    }

    func messageSource(_ source: AgentMessageSource, didRequestProximity event: String) {
        pendingProximityEvent = event
        isAwaitingNavigation = true
        delegate?.callSessionNeedsChatVisible(self)
        delegate?.callSessionDidChangeNavigationPrompt(self)
    }

    func messageSourceDidRequestHints(_ source: AgentMessageSource) {
        delegate?.callSessionNeedsChatVisible(self)
        presentAnswerOptions()
    }

    func messageSource(_ source: AgentMessageSource, didComplete event: String) {
        SessionRecorder.shared.logEvent(event)
    }

    func messageSourceDidRequestFinalize(_ source: AgentMessageSource) {
        isAwaitingFinalize = true
        delegate?.callSessionNeedsChatVisible(self)
        delegate?.callSessionDidChangeFinalizePrompt(self)
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
