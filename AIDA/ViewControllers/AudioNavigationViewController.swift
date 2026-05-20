import UIKit

final class AudioNavigationViewController: UIViewController {
    private let viewModel: AudioNavigationViewModel
    private let pulseView = UIView()
    private let statusLabel = UILabel()

    init(viewModel: AudioNavigationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPulse()
        viewModel.startNarration()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopNarration()
    }

    private func setupViews() {
        pulseView.backgroundColor = Theme.accent
        pulseView.layer.cornerRadius = 60
        pulseView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pulseView)

        statusLabel.text = viewModel.statusText
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 17, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            pulseView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pulseView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            pulseView.widthAnchor.constraint(equalToConstant: 120),
            pulseView.heightAnchor.constraint(equalToConstant: 120),

            statusLabel.topAnchor.constraint(equalTo: pulseView.bottomAnchor, constant: 32),
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    private func startPulse() {
        UIView.animate(withDuration: 1.2,
                       delay: 0,
                       options: [.repeat, .autoreverse, .allowUserInteraction],
                       animations: {
            self.pulseView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.pulseView.alpha = 0.4
        })
    }
}
