import Foundation

final class AudioNavigationViewModel {
    var statusText: String { L10n.audioNavigationStatus.current }
    private let sampleSpeech: String

    private let speechService = SpeechService()

    init() {
        self.sampleSpeech = L10n.audioNavigationSampleSpeech.current
    }

    func startNarration() {
        speechService.speak(sampleSpeech)
    }

    func stopNarration() {
        speechService.stop()
    }
}
