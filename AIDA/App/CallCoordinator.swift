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
        // Opens by asking the user to confirm they can hear, then continues the
        // briefing once an affirmative answer arrives.
        var steps: [AgentScriptStep] = [
            .ask(
                question: L10n.activeCallQuestionHearMe.current,
                retry: L10n.activeCallRetryHearMe.current,
                accept: { isAffirmative($0) }
            )
        ]
        steps += L10n.activeCallScript.map { .say($0.current) }
        let source = ScriptedAgentMessageSource(
            steps: steps,
            firstDelay: 2.0,
            interMessageDelay: 6.0,
            postAnswerDelay: 1.0
        )
        return CallSession(chatViewModel: chatViewModel, messageSource: source)
    }

    /// Lenient yes-detection in the current language; anything else counts as "no".
    private static func isAffirmative(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let affirmatives: [String]
        switch LocalizationManager.shared.currentLanguage {
        case .italian:
            affirmatives = ["sì", "si", "certo", "ti sento", "affermativo", "perfetto", "ok"]
        case .english:
            affirmatives = ["yes", "yeah", "yep", "yup", "i can", "hear you", "affirmative", "ok", "okay"]
        }
        return affirmatives.contains { normalized.contains($0) }
    }

    func start() {
        let chat = ChatViewController(viewModel: chatViewModel)
        chat.onBack = { [weak self] in self?.confirmAbandon() }
        chat.onReturnToCall = { [weak self] in self?.handleBannerTapped() }
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
