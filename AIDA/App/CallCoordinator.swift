import UIKit

/// Drives the simulated-call experience: chat as the base screen, the full call
/// presented over it, and a "tap to return to call" banner on the chat while the
/// call is minimized. Owns the `CallSession` and is its delegate, fanning state
/// changes out to whichever UI is currently visible.
@MainActor
final class CallCoordinator: NSObject {
    private let navigationController: UINavigationController
    private let chatViewModel: ChatViewModel
    private var session: CallSession

    private weak var chatVC: ChatViewController?
    private var activeCallVC: ActiveCallViewController?

    /// Called once the call has ended and teardown is complete.
    var onFinished: (() -> Void)?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.chatViewModel = ChatViewModel()
        self.session = CallCoordinator.makeSession(chatViewModel: chatViewModel)
        super.init()
        session.delegate = self
    }

    private static func makeSession(chatViewModel: ChatViewModel) -> CallSession {
        let source = ScriptedAgentMessageSource(
            steps: demoMissionSteps(),
            firstDelay: 2.0,
            interMessageDelay: 6.0,
            postAnswerDelay: 1.0
        )
        return CallSession(chatViewModel: chatViewModel, messageSource: source)
    }

    /// The hardcoded demo mission: 2 checkpoints, a photo enigma, a proximity
    /// search, and a multiple-choice enigma with hints.
    private static func demoMissionSteps() -> [AgentScriptStep] {
        [
            // Opening: confirm the user can hear (shows the answer mechanism).
            .ask(
                question: L10n.activeCallQuestionHearMe.current,
                retry: L10n.activeCallRetryHearMe.current,
                accept: { isAffirmative($0) },
                help: { _ in false },
                helpOffer: nil,
                helpOfferAccept: nil
            ),

            // Intro
            .say(L10n.demoIntro.current),
            .map(bearingDegrees: 0, distanceMeters: 100),

            // Checkpoint 1 — photo enigma
            .checkpoint(event: "CHECKPOINT_1_REACHED"),
            .say(L10n.demoCheckpoint1Praise.current),
            .say(L10n.demoPhotoInstruction.current),
            .camera,
            .loading(text: L10n.demoValidatingClue.current, seconds: 2.5),
            .success(L10n.demoAnalysisComplete.current),
            .say(L10n.demoPrepareNext.current),
            .map(bearingDegrees: 0, distanceMeters: 100),

            // Checkpoint 2 — proximity search
            .checkpoint(event: "CHECKPOINT_2_REACHED"),
            .say(L10n.demoOhNo.current),
            .sayQuick(L10n.demoLosingGPS.current),
            .sayQuick(L10n.demoFollowSignal.current),
            .proximity(event: "CHECKPOINT_2_PROXIMITY_FOUND",
                       confirmation: L10n.demoProximityAcquired.current),

            // Checkpoint 2 — statues lead-in, then the date enigma with sources
            .ask(
                question: L10n.demoStatuesPrompt.current,
                retry: L10n.demoStatuesRetry.current,
                accept: { isAffirmative($0) },
                help: { _ in false },
                helpOffer: nil,
                helpOfferAccept: nil
            ),
            .ask(
                question: L10n.demoYearQuestion.current,
                retry: L10n.demoEnigmaRetry.current,
                accept: { isEnigmaCorrect($0) },
                help: { isHelpRequest($0) },
                helpOffer: L10n.demoSourcesOffer.current,
                helpOfferAccept: { isAffirmative($0) }
            ),
            .say(L10n.demoEnigmaCorrect.current),
            .say(L10n.demoMissionComplete.current),
            .say(L10n.demoWellDone.current),
            .complete(event: "MISSION_COMPLETED"),
            .finalize
        ]
    }

    /// Lenient yes-detection. Accepts either language so a "yes" / "sì" always
    /// works regardless of the app's current language.
    private static func isAffirmative(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let affirmatives = [
            "sì", "si", "certo", "ti sento", "affermativo", "perfetto", "va bene",
            "yes", "yeah", "yep", "yup", "i can", "hear you", "affirmative", "ok", "okay"
        ]
        return affirmatives.contains { normalized.contains($0) }
    }

    private static func isEnigmaCorrect(_ text: String) -> Bool {
        let s = text.lowercased()
        return s.contains("1812") || s.contains("mille ottocento") || s.contains("milleottocento")
    }

    private static func isHelpRequest(_ text: String) -> Bool {
        // Normalize the curly apostrophe iOS substitutes ("don't" -> "don't").
        let s = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        return s.contains("non lo so") || s.contains("non so") || s.contains("non saprei")
            || s.contains("boh") || s.contains("idk")
            || s.contains("don't know") || s.contains("dont know") || s.contains("no idea")
    }

    func start() {
        let chat = ChatViewController(viewModel: chatViewModel)
        chat.onBack = { [weak self] in self?.confirmAbandon() }
        chat.onReturnToCall = { [weak self] in self?.handleBannerTapped() }
        chat.onCheckpoint = { [weak self] in self?.session.checkpointReached() }
        chat.onCamera = { [weak self] in self?.presentCamera() }
        chat.onNavigate = { [weak self] in self?.presentProximity() }
        chat.onFinalize = { [weak self] in self?.presentMissionReport() }
        // Typed messages double as answers while the agent is awaiting one.
        chatViewModel.userMessageInterceptor = { [weak self] text in
            guard let self, self.session.isAwaitingAnswer else { return false }
            self.session.submitTypedAnswer(text)
            return true
        }
        chatVC = chat
        // Replace the one-time incoming-call screen (currently top of the stack)
        // with the chat, so it never reappears when the user navigates back.
        var stack = navigationController.viewControllers
        if !stack.isEmpty {
            stack.removeLast()
        }
        stack.append(chat)
        navigationController.setViewControllers(stack, animated: false)
        presentFullCall(animated: true)
        session.start()
    }

    // MARK: - Presentation

    private func presentFullCall(animated: Bool) {
        let vc = ActiveCallViewController(session: session)
        vc.onMinimize = { [weak self] in self?.minimize() }
        activeCallVC = vc
        navigationController.present(vc, animated: animated)
    }

    private func minimize() {
        activeCallVC?.dismiss(animated: true)
        activeCallVC = nil
        // In-call: show the green banner, not the top-right button.
        chatVC?.setReturnButtonVisible(false)
        chatVC?.setCallBannerText(bannerText)
        chatVC?.setCallBannerVisible(true)
    }

    /// Both affordances route here: returning to a running (minimized) call, and
    /// starting a fresh call once the previous one has ended.
    private func handleBannerTapped() {
        if session.hasEnded {
            recall()
        } else {
            restore()
        }
    }

    private func restore() {
        chatVC?.setCallBannerVisible(false)
        presentFullCall(animated: true)
    }

    private func recall() {
        chatVC?.setReturnButtonVisible(false)
        session = CallCoordinator.makeSession(chatViewModel: chatViewModel)
        session.delegate = self
        presentFullCall(animated: true)
        session.start()
    }

    private var bannerText: String {
        "\(L10n.activeCallReturnBanner.current)  ·  \(session.durationText)"
    }

    /// The view controller to present mission modals from (over the call screen
    /// if it's up, otherwise over the chat).
    private var topPresenter: UIViewController {
        navigationController.presentedViewController ?? navigationController
    }

    private func presentCamera() {
        let cameraVC = FakeCameraViewController(viewModel: FakeCameraViewModel())
        cameraVC.onCapture = { [weak self, weak cameraVC] in
            cameraVC?.dismiss(animated: true) { self?.session.cameraCaptured() }
        }
        topPresenter.present(cameraVC, animated: true)
    }

    private func presentProximity() {
        let proximityVC = AudioNavigationViewController(viewModel: AudioNavigationViewModel())
        proximityVC.modalPresentationStyle = .fullScreen
        proximityVC.onTargetFound = { [weak self, weak proximityVC] in
            proximityVC?.dismiss(animated: true) { self?.session.proximityFound() }
        }
        topPresenter.present(proximityVC, animated: true)
    }

    private func presentMissionReport() {
        let reportVC = MissionReportViewController(viewModel: MissionReportViewModel())
        reportVC.onCollect = { [weak self] in
            guard let self else { return }
            // End the call and return to the main screen.
            if !self.session.hasEnded { self.session.hangUp() }
            self.navigationController.popToRootViewController(animated: false)
            reportVC.dismiss(animated: true)
            self.onFinished?()
        }
        topPresenter.present(reportVC, animated: true)
    }

    private func refresh() {
        activeCallVC?.render()
        if !session.hasEnded {
            chatVC?.setCallBannerText(bannerText)
        }
    }

    // MARK: - Abandon

    private func confirmAbandon() {
        let alert = UIAlertController(
            title: L10n.abandonMissionTitle.current,
            message: L10n.abandonMissionMessage.current,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.abandonMissionConfirm.current, style: .destructive) { [weak self] _ in
            self?.abandon()
        })
        alert.addAction(UIAlertAction(title: L10n.abandonMissionCancel.current, style: .cancel))
        navigationController.present(alert, animated: true)
    }

    private func abandon() {
        if !session.hasEnded {
            session.hangUp()
        }
        navigationController.popToRootViewController(animated: true)
        onFinished?()
    }
}

extension CallCoordinator: CallSessionDelegate {
    func callSessionDidTick(_ session: CallSession) { refresh() }
    func callSessionDidChangeSpeaking(_ session: CallSession) { refresh() }
    func callSessionDidChangeControls(_ session: CallSession) { refresh() }
    func callSessionDidChangeInteraction(_ session: CallSession) { refresh() }

    func callSessionDidChangeCheckpoint(_ session: CallSession) {
        chatVC?.setCheckpointVisible(session.isAwaitingCheckpoint)
    }

    func callSessionDidChangeCameraPrompt(_ session: CallSession) {
        chatVC?.setCameraVisible(session.isAwaitingPhoto)
    }

    func callSessionDidChangeNavigationPrompt(_ session: CallSession) {
        chatVC?.setNavigationVisible(session.isAwaitingNavigation)
    }

    func callSessionDidChangeFinalizePrompt(_ session: CallSession) {
        chatVC?.setFinalizeVisible(session.isAwaitingFinalize)
    }

    func callSessionNeedsChatVisible(_ session: CallSession) {
        // A mission element appeared in the chat; if the full call screen is
        // covering it, minimize so the user can see/interact with it.
        if activeCallVC != nil {
            minimize()
        }
    }

    func callSessionDidEnd(_ session: CallSession) {
        // Stop the call UI but keep the chat visible and scrollable underneath.
        // The coordinator stays alive so it can still manage the chat's back
        // button; it's released only when the user abandons the mission.
        activeCallVC?.dismiss(animated: true)
        activeCallVC = nil
        // Not in a call anymore: hide the banner, show the top-right button.
        chatVC?.setCallBannerVisible(false)
        chatVC?.setReturnButtonVisible(true)
    }
}
