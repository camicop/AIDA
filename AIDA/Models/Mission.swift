import UIKit

struct Mission {
    enum ID: String {
        case councilSeal
        case operationAdige
        case baseOmega
    }

    let id: ID
    let title: LocalizedString
    let subtitle: LocalizedString
    let briefing: LocalizedString
    let estimatedDuration: LocalizedString
    let iconName: String
    let accentTop: UIColor
    let accentBottom: UIColor
}

extension Mission {
    static let catalog: [Mission] = [
        Mission(
            id: .councilSeal,
            title: L10n.storyCouncilSealTitle,
            subtitle: L10n.storyCouncilSealSubtitle,
            briefing: L10n.storyCouncilSealBriefing,
            estimatedDuration: L10n.missionDurationPlaceholder,
            iconName: "scroll.fill",
            accentTop: UIColor(red: 0.45, green: 0.20, blue: 0.55, alpha: 1.0),
            accentBottom: UIColor(red: 0.20, green: 0.08, blue: 0.30, alpha: 1.0)
        ),
        Mission(
            id: .operationAdige,
            title: L10n.storyOperationAdigeTitle,
            subtitle: L10n.storyOperationAdigeSubtitle,
            briefing: L10n.storyOperationAdigeBriefing,
            estimatedDuration: L10n.missionDurationPlaceholder,
            iconName: "shield.lefthalf.filled",
            accentTop: UIColor(red: 0.70, green: 0.18, blue: 0.20, alpha: 1.0),
            accentBottom: UIColor(red: 0.35, green: 0.06, blue: 0.10, alpha: 1.0)
        ),
        Mission(
            id: .baseOmega,
            title: L10n.storyBaseOmegaTitle,
            subtitle: L10n.storyBaseOmegaSubtitle,
            briefing: L10n.storyBaseOmegaBriefing,
            estimatedDuration: L10n.missionDurationPlaceholder,
            iconName: "antenna.radiowaves.left.and.right",
            accentTop: UIColor(red: 0.10, green: 0.30, blue: 0.55, alpha: 1.0),
            accentBottom: UIColor(red: 0.04, green: 0.12, blue: 0.28, alpha: 1.0)
        )
    ]
}
