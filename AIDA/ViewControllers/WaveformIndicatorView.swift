import UIKit

/// A row of bars that animate up and down while the agent is "speaking".
/// Purely decorative — driven by `isAnimating`, not by real audio levels.
final class WaveformIndicatorView: UIView {
    private let barCount: Int
    private let barWidth: CGFloat = 5
    private let barSpacing: CGFloat = 6
    private let minScale: CGFloat = 0.3

    private var bars: [UIView] = []

    private(set) var isAnimating = false

    init(barCount: Int = 5, color: UIColor = Theme.accent) {
        self.barCount = barCount
        super.init(frame: .zero)
        setupBars(color: color)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBars(color: UIColor) {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = barSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for _ in 0..<barCount {
            let bar = UIView()
            bar.backgroundColor = color
            bar.layer.cornerRadius = barWidth / 2
            bar.translatesAutoresizingMaskIntoConstraints = false
            bars.append(bar)
            // Add to the stack first so the bar and stack share an ancestor
            // before the height constraint between them is activated.
            stack.addArrangedSubview(bar)
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: barWidth),
                bar.heightAnchor.constraint(equalTo: stack.heightAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.heightAnchor.constraint(equalTo: heightAnchor)
        ])

        resetBars()
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        for (index, bar) in bars.enumerated() {
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = minScale
            animation.toValue = 1.0
            animation.duration = 0.4 + Double(index % 3) * 0.12
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.08
            bar.layer.add(animation, forKey: "waveform")
        }
    }

    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        for bar in bars {
            bar.layer.removeAnimation(forKey: "waveform")
        }
        resetBars()
    }

    private func resetBars() {
        for bar in bars {
            bar.transform = CGAffineTransform(scaleX: 1, y: minScale)
        }
    }
}
