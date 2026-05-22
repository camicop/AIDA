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
    static var localizedAll: [Permission] {
        [
            Permission(kind: .gps,
                       title: L10n.permissionGPSTitle.current,
                       description: L10n.permissionGPSDescription.current,
                       iconName: "location.fill",
                       isMandatory: true),
            Permission(kind: .microphone,
                       title: L10n.permissionMicrophoneTitle.current,
                       description: L10n.permissionMicrophoneDescription.current,
                       iconName: "mic.fill",
                       isMandatory: false),
            Permission(kind: .camera,
                       title: L10n.permissionCameraTitle.current,
                       description: L10n.permissionCameraDescription.current,
                       iconName: "camera.fill",
                       isMandatory: false),
            Permission(kind: .healthKit,
                       title: L10n.permissionHealthKitTitle.current,
                       description: L10n.permissionHealthKitDescription.current,
                       iconName: "heart.fill",
                       isMandatory: false)
        ]
    }
}
