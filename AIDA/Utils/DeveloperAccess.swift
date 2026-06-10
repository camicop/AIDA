import UIKit

extension UIViewController {
    func enableDeveloperModeAccess() {
        let label = TapCounterLabel()
        label.text = navigationItem.title ?? title ?? ""
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.isUserInteractionEnabled = true
        label.requiredTapCount = 7
        label.resetInterval = 2.0
        label.onThresholdReached = { [weak self] in
            self?.presentDeveloperMode()
        }
        navigationItem.titleView = label
    }

    private func presentDeveloperMode() {
        guard presentedViewController == nil else { return }
        let vm = DeveloperViewModel()
        let vc = DeveloperViewController(viewModel: vm)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}

private final class TapCounterLabel: UILabel {
    var requiredTapCount: Int = 7
    var resetInterval: TimeInterval = 2.0
    var onThresholdReached: (() -> Void)?

    private var tapCount = 0
    private var resetWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        let minWidth: CGFloat = 120
        return CGSize(width: max(base.width, minWidth), height: max(base.height, 32))
    }

    @objc private func handleTap() {
        tapCount += 1
        resetWorkItem?.cancel()
        if tapCount >= requiredTapCount {
            tapCount = 0
            onThresholdReached?()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.tapCount = 0
        }
        resetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + resetInterval, execute: work)
    }
}
