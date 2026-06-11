import UIKit

struct ChatMessage {
    enum Sender {
        case user
        case agent
    }

    enum Kind {
        case text(String)
        case image(UIImage)
        case hints(HintOptionGroup)
        /// Green "success" bubble with a checkmark (e.g. analysis complete).
        case success(String)
        /// Transient spinner row with a label (e.g. "Validating clue…").
        case loading(String)
        /// Transient animated "typing…" dots.
        case typing
    }

    let sender: Sender
    let kind: Kind

    init(sender: Sender, kind: Kind) {
        self.sender = sender
        self.kind = kind
    }

    init(sender: Sender, text: String) {
        self.init(sender: sender, kind: .text(text))
    }

    init(sender: Sender, image: UIImage) {
        self.init(sender: sender, kind: .image(image))
    }

    init(sender: Sender, hints: HintOptionGroup) {
        self.init(sender: sender, kind: .hints(hints))
    }

    /// Transient rows that should be cleared before a real message is appended.
    var isTransient: Bool {
        switch kind {
        case .loading, .typing: return true
        default: return false
        }
    }
}

/// A set of tappable answer-choice cards shown inline in the chat. Tapping one
/// submits its `value` as the user's answer. Reference type so the closure can
/// capture and mutate it.
final class HintOptionGroup {
    struct Option {
        /// What the user sees on the card (e.g. "1812").
        let title: String
        /// What gets submitted as the answer when tapped.
        let value: String
    }

    let options: [Option]
    /// Called with the tapped option index.
    var onSelect: ((Int) -> Void)?

    init(options: [Option]) {
        self.options = options
    }
}
