import Foundation

struct ChatMessage {
    enum Sender {
        case user
        case agent
    }

    let sender: Sender
    let text: String
}
