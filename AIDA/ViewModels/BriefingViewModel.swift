import Foundation

protocol BriefingViewModelDelegate: AnyObject {
    func briefingDidConfirm(_ viewModel: BriefingViewModel)
}

protocol BriefingViewModelBinding: AnyObject {
    func briefingViewModelDidChangePlaybackState(_ viewModel: BriefingViewModel)
    func briefingViewModel(_ viewModel: BriefingViewModel, didUpdateSpokenLocation location: Int)
}

final class BriefingViewModel {
    weak var delegate: BriefingViewModelDelegate?
    weak var binding: BriefingViewModelBinding?

    let mission: Mission

    var screenTitle: String { L10n.briefingTitle.current }
    let briefingText: String
    var readyButtonTitle: String { L10n.briefingReady.current }

    var playButtonTitle: String {
        switch playbackState {
        case .idle:
            return speechStartOffset > 0
                ? L10n.briefingResume.current
                : L10n.briefingListen.current
        case .speaking:
            return L10n.briefingPause.current
        case .paused:
            return L10n.briefingResume.current
        }
    }

    var playButtonIconName: String {
        switch playbackState {
        case .idle, .paused: return "play.fill"
        case .speaking: return "pause.fill"
        }
    }

    private(set) var playbackState: SpeechService.State = .idle
    private(set) var spokenLocation: Int = 0

    private let speechService = SpeechService()
    private var speechStartOffset: Int = 0

    init(mission: Mission) {
        self.mission = mission
        self.briefingText = mission.briefing.current
        speechService.delegate = self
    }

    func togglePlayback() {
        switch playbackState {
        case .idle:
            let nsText = briefingText as NSString
            let start = min(max(0, speechStartOffset), nsText.length)
            if start >= nsText.length {
                speechStartOffset = 0
                spokenLocation = 0
                binding?.briefingViewModel(self, didUpdateSpokenLocation: 0)
                speechService.speak(briefingText)
            } else {
                spokenLocation = start
                binding?.briefingViewModel(self, didUpdateSpokenLocation: start)
                let substring = nsText.substring(from: start)
                speechService.speak(substring)
            }
        case .speaking:
            speechService.pause()
        case .paused:
            speechService.resume()
        }
    }

    func seek(toCharacterIndex index: Int) {
        let wordStart = wordStart(at: index)
        speechService.stop()
        speechStartOffset = wordStart
        spokenLocation = wordStart
        binding?.briefingViewModel(self, didUpdateSpokenLocation: wordStart)
        binding?.briefingViewModelDidChangePlaybackState(self)
    }

    func previewSpokenLocation(at index: Int) {
        let wordStart = wordStart(at: index)
        spokenLocation = wordStart
        binding?.briefingViewModel(self, didUpdateSpokenLocation: wordStart)
    }

    func confirmReady() {
        speechService.stop()
        delegate?.briefingDidConfirm(self)
    }

    private func wordStart(at index: Int) -> Int {
        let nsText = briefingText as NSString
        let safeIndex = min(max(0, index), nsText.length)
        if safeIndex == 0 { return 0 }
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let prefixRange = NSRange(location: 0, length: safeIndex)
        let lastSeparator = nsText.rangeOfCharacter(from: separators, options: .backwards, range: prefixRange)
        if lastSeparator.location == NSNotFound { return 0 }
        return lastSeparator.location + lastSeparator.length
    }
}

extension BriefingViewModel: SpeechServiceDelegate {
    func speechService(_ service: SpeechService, didChangeState state: SpeechService.State) {
        playbackState = state
        binding?.briefingViewModelDidChangePlaybackState(self)
    }

    func speechService(_ service: SpeechService, willSpeakRange range: NSRange) {
        spokenLocation = speechStartOffset + range.location + range.length
        binding?.briefingViewModel(self, didUpdateSpokenLocation: spokenLocation)
    }

    func speechServiceDidFinish(_ service: SpeechService) {
        spokenLocation = (briefingText as NSString).length
        speechStartOffset = 0
        binding?.briefingViewModel(self, didUpdateSpokenLocation: spokenLocation)
    }
}
