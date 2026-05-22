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
        state = .idle
        delegate?.speechServiceDidFinish(self)
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
