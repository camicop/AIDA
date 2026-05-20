import Foundation

final class AudioNavigationViewModel {
    let statusText = "In ascolto…"
    let sampleSpeech = "Procedi dritto per cinquanta metri, poi gira a sinistra. Quando senti il segnale, fermati e ascolta."

    private let speechService: SpeechService

    init(speechService: SpeechService) {
        self.speechService = speechService
    }

    func startNarration() {
        speechService.speak(sampleSpeech)
    }

    func stopNarration() {
        speechService.stop()
    }
}
