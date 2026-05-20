import Foundation

struct Permission {
    enum Kind: Hashable {
        case gps
        case microphone
        case camera
        case healthKit
    }

    let kind: Kind
    let title: String
    let description: String
    let iconName: String
    let isMandatory: Bool
}

extension Permission {
    static let all: [Permission] = [
        Permission(kind: .gps,
                   title: "Posizione",
                   description: "Indispensabile per guidarti tra le tappe della missione.",
                   iconName: "location.fill",
                   isMandatory: true),
        Permission(kind: .microphone,
                   title: "Microfono",
                   description: "Per parlare con l'agente AI durante l'avventura.",
                   iconName: "mic.fill",
                   isMandatory: false),
        Permission(kind: .camera,
                   title: "Fotocamera",
                   description: "Per scattare foto agli indizi e ai luoghi visitati.",
                   iconName: "camera.fill",
                   isMandatory: false),
        Permission(kind: .healthKit,
                   title: "HealthKit",
                   description: "Adatta il ritmo della missione al tuo stato di forma.",
                   iconName: "heart.fill",
                   isMandatory: false)
    ]
}
