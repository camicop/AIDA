import Foundation

final class MissionReportViewModel {
    var screenTitle: String { L10n.reportTitle.current }
    var subtitle: String { L10n.reportSubtitle.current }
    var summaryHeader: String { L10n.reportSummaryHeader.current }
    var summaryPoints: [String] {
        [
            L10n.reportPoint1.current,
            L10n.reportPoint2.current,
            L10n.reportPoint3.current,
            L10n.reportPoint4.current
        ]
    }
    var pointsLabel: String { L10n.reportPointsLabel.current }
    var collectButtonTitle: String { L10n.reportCollectButton.current }

    /// Points earned for the demo mission.
    let points = 275
    var pointsText: String { "\(points)" }
}
