import AVFoundation

protocol SpeechServiceDelegate: AnyObject {
    func speechService(_ service: SpeechService, didChangeState state: SpeechService.State)
    func speechService(_ service: SpeechService, willSpeakRange range: NSRange)
    func speechServiceDidFinish(_ service: SpeechService)
}

extension SpeechServiceDelegate {
    func speechService(_ service: SpeechService, didChangeState state: SpeechService.State) {}
    func speechService(_ service: SpeechService, willSpeakRange range: NSRange) {}
    func speechServiceDidFinish(_ service: SpeechService) {}
}

final class SpeechService: NSObject {
    enum State {
        case idle
        case speaking
        case paused
    }

    private static let warmUpSynthesizer = AVSpeechSynthesizer()

    static func warmUp() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])

        let voices = AVSpeechSynthesisVoice.speechVoices()
        for language in Language.allCases {
            if let name = language.preferredVoiceName,
               let voice = voices.first(where: { $0.language == language.bcp47 && $0.name == name }) {
                _ = voice
            } else {
                _ = AVSpeechSynthesisVoice(language: language.bcp47)
            }
        }

        let utterance = AVSpeechUtterance(string: "a")
        utterance.volume = 0
        warmUpSynthesizer.speak(utterance)
    }

    weak var delegate: SpeechServiceDelegate?

    private(set) var state: State = .idle {
        didSet {
            guard oldValue != state else { return }
            delegate?.speechService(self, didChangeState: state)
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    /// FIFO of texts waiting to be spoken when the queue API is used.
    private var pendingTexts: [String] = []

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("SpeechService: audio session setup failed — \(error)")
        }
    }

    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = resolveVoice(for: LocalizationManager.shared.currentLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// Adds text to the speak queue. Utterances are spoken strictly in order,
    /// one after another (advanced from the synthesizer's didFinish delegate),
    /// so they never overlap. Use this instead of `speak(_:)` for a call.
    func enqueue(_ text: String) {
        // Split into sentences so each ends with a short pause (a longer beat
        // after periods than the synthesizer's default).
        pendingTexts.append(contentsOf: Self.splitIntoSentences(text))
        if state == .idle, !synthesizer.isSpeaking {
            speakNext()
        }
    }

    /// Clears the pending queue and stops any current utterance.
    func flushQueue() {
        pendingTexts.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speakNext() {
        guard !pendingTexts.isEmpty else { return }
        let text = pendingTexts.removeFirst()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = resolveVoice(for: LocalizationManager.shared.currentLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // Extra silence after each sentence so periods land with a beat.
        utterance.postUtteranceDelay = 0.45
        synthesizer.speak(utterance)
    }

    /// Splits text into sentences, keeping the trailing punctuation. Falls back
    /// to the whole string if no sentence terminators are present.
    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "." || character == "!" || character == "?" || character == "…" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty { sentences.append(trailing) }
        return sentences.isEmpty ? [text] : sentences
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func resolveVoice(for language: Language) -> AVSpeechSynthesisVoice? {
        let key = "\(language.bcp47)|\(language.preferredVoiceName ?? "")"
        if let cached = voiceCache[key] { return cached }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        let resolved: AVSpeechSynthesisVoice?
        if let name = language.preferredVoiceName,
           let preferred = voices.first(where: { $0.language == language.bcp47 && $0.name == name }) {
            resolved = preferred
        } else {
            resolved = AVSpeechSynthesisVoice(language: language.bcp47)
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }

        if let resolved {
            voiceCache[key] = resolved
        }
        return resolved
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        state = .speaking
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        state = .paused
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        state = .speaking
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !pendingTexts.isEmpty {
            // Advance the queue: keep "speaking" without an idle flicker.
            speakNext()
        } else {
            state = .idle
            delegate?.speechServiceDidFinish(self)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        state = .idle
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        delegate?.speechService(self, willSpeakRange: characterRange)
    }
}
