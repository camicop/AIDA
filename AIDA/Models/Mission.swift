import Foundation

struct Mission {
    let title: String
    let subtitle: String
    let estimatedDuration: String
}

extension Mission {
    static var localizedPlaceholders: [Mission] {
        [
            Mission(title: L10n.missionExplorativeTitle.current,
                    subtitle: L10n.missionExplorativeSubtitle.current,
                    estimatedDuration: L10n.missionExplorativeDuration.current),
            Mission(title: L10n.missionRunTitle.current,
                    subtitle: L10n.missionRunSubtitle.current,
                    estimatedDuration: L10n.missionRunDuration.current)
        ]
    }
}
