import Foundation
import Speech
import AVFoundation

@MainActor
protocol SpeechRecognitionServiceDelegate: AnyObject {
    func speechRecognition(_ service: SpeechRecognitionService, didProducePartial text: String)
    func speechRecognition(_ service: SpeechRecognitionService, didFinishWith text: String)
    func speechRecognitionDidFail(_ service: SpeechRecognitionService)
}

/// Wraps SFSpeechRecognizer + AVAudioEngine for short, tap-to-talk answers.
/// Reports live partial transcripts and auto-finalizes after a brief silence.
@MainActor
final class SpeechRecognitionService: NSObject {
    weak var delegate: SpeechRecognitionServiceDelegate?

    private(set) var isListening = false

    private var audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var latestTranscript = ""
    private var hasHeardSpeech = false

    /// Grace period to start talking after tapping the mic.
    private let noSpeechTimeout: TimeInterval = 5.0
    /// Silence after speech has begun that finalizes the answer.
    private let silenceTimeout: TimeInterval = 1.5

    /// Asks up front for both speech-recognition and microphone permission so the
    /// prompts are out of the way before the user needs to answer.
    static func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func startListening(locale: Locale) {
        guard !isListening else { return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            delegate?.speechRecognitionDidFail(self)
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        // Use a fresh engine each time so a previously-presented screen that
        // touched audio can't leave stale state that makes start() throw.
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cleanup()
            delegate?.speechRecognitionDidFail(self)
            return
        }

        latestTranscript = ""
        hasHeardSpeech = false
        isListening = true
        armSilenceTimer()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Callback runs off the main actor; hop back before touching state.
            Task { @MainActor in
                guard let self, self.isListening else { return }
                if let result {
                    self.latestTranscript = result.bestTranscription.formattedString
                    self.hasHeardSpeech = true
                    self.delegate?.speechRecognition(self, didProducePartial: self.latestTranscript)
                    self.armSilenceTimer()
                    if result.isFinal {
                        self.finish()
                    }
                }
                if error != nil {
                    self.finish()
                }
            }
        }
    }

    /// Stops recording without delivering a result (used on hang up).
    func cancel() {
        guard isListening else { return }
        cleanup()
    }

    private func armSilenceTimer() {
        silenceTimer?.invalidate()
        let timeout = hasHeardSpeech ? silenceTimeout : noSpeechTimeout
        silenceTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }
    }

    private func finish() {
        guard isListening else { return }
        let text = latestTranscript
        cleanup()
        delegate?.speechRecognition(self, didFinishWith: text)
    }

    private func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
    }
}
