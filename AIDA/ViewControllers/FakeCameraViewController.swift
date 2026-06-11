import UIKit

/// A fake camera viewfinder. No real capture — tapping the shutter plays a flash
/// and reports completion via `onCapture`.
final class FakeCameraViewController: UIViewController {
    private let viewModel: FakeCameraViewModel
    var onCapture: (() -> Void)?

    private let overlayLabel = UILabel()
    private let shutterButton = UIButton(type: .system)
    private let flashView = UIView()

    init(viewModel: FakeCameraViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupViews()
    }

    private func setupViews() {
        // Simple viewfinder framing brackets in the center.
        let frame = UIView()
        frame.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        frame.layer.borderWidth = 2
        frame.layer.cornerRadius = 12
        frame.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frame)

        overlayLabel.text = viewModel.overlayText
        overlayLabel.textColor = .white
        overlayLabel.font = .systemFont(ofSize: 17, weight: .medium)
        overlayLabel.textAlignment = .center
        overlayLabel.numberOfLines = 0
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayLabel)

        // White ring shutter, like a camera app.
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 64))
        config.baseForegroundColor = .white
        shutterButton.configuration = config
        shutterButton.layer.borderColor = UIColor.white.cgColor
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.cornerRadius = 40
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)
        view.addSubview(shutterButton)

        flashView.backgroundColor = .white
        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false
        flashView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flashView)

        NSLayoutConstraint.activate([
            frame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frame.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frame.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            frame.heightAnchor.constraint(equalTo: frame.widthAnchor),

            overlayLabel.bottomAnchor.constraint(equalTo: frame.topAnchor, constant: -24),
            overlayLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            overlayLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            shutterButton.widthAnchor.constraint(equalToConstant: 80),
            shutterButton.heightAnchor.constraint(equalToConstant: 80),

            flashView.topAnchor.constraint(equalTo: view.topAnchor),
            flashView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            flashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flashView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    @objc private func didTapShutter() {
        shutterButton.isEnabled = false
        UIView.animate(withDuration: 0.08, animations: {
            self.flashView.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, animations: {
                self.flashView.alpha = 0
            }, completion: { _ in
                self.onCapture?()
            })
        })
    }
}
