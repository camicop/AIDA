import CoreLocation

protocol MapViewModelDelegate: AnyObject {
    func mapViewModel(_ viewModel: MapViewModel, didConfirm area: MissionArea)
    func mapViewModelDidCancel(_ viewModel: MapViewModel)
}

final class MapViewModel {
    weak var delegate: MapViewModelDelegate?

    let zones: [Zone] = Zone.catalog
    let maxDiameterMeters: Double = 4000
    let nearestZoneSnapMeters: Double = 2000
    let initialArea: MissionArea?

    init(initialArea: MissionArea? = nil) {
        self.initialArea = initialArea
    }

    var screenTitle: String { L10n.mapTitle.current }
    var cancelTitle: String { L10n.mapCancel.current }
    var openSettingsTitle: String { L10n.mapOpenSettings.current }
    var gpsDeniedTitle: String { L10n.mapGPSDeniedTitle.current }
    var gpsDeniedMessage: String { L10n.mapGPSDeniedMessage.current }
    var confirmAreaTitle: String { L10n.mapConfirmArea.current }
    var diameterDisclaimer: String { L10n.mapDiameterDisclaimer.current }

    func diameterLabel(forDiameterMeters meters: Double) -> String {
        String(format: L10n.mapDiameterFormat.current, meters / 1000)
    }

    func didConfirmArea(center: CLLocationCoordinate2D, radiusMeters: Double) {
        guard radiusMeters * 2 <= maxDiameterMeters else { return }
        let area = MissionArea(
            center: center,
            radiusMeters: radiusMeters,
            nearestZoneName: MissionArea.nearestZoneName(
                to: center,
                within: nearestZoneSnapMeters,
                in: zones
            )
        )
        delegate?.mapViewModel(self, didConfirm: area)
    }

    func didCancel() {
        delegate?.mapViewModelDidCancel(self)
    }
}
