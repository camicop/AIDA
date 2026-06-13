import CoreLocation

struct Zone {
    let id: String
    let name: LocalizedString
    let center: CLLocationCoordinate2D
    let checkpointCount: Int
}

extension Zone {
    static let catalog: [Zone] = [
        Zone(
            id: "buonconsiglio",
            name: L10n.zoneBuonconsiglio,
            center: CLLocationCoordinate2D(latitude: 46.0748, longitude: 11.1268),
            checkpointCount: 3
        ),
        Zone(
            id: "piazzaDuomo",
            name: L10n.zonePiazzaDuomo,
            center: CLLocationCoordinate2D(latitude: 46.0664, longitude: 11.1213),
            checkpointCount: 4
        ),
        Zone(
            id: "piazzaFiera",
            name: L10n.zonePiazzaFiera,
            center: CLLocationCoordinate2D(latitude: 46.0690, longitude: 11.1175),
            checkpointCount: 2
        ),
        Zone(
            id: "santaMariaMaggiore",
            name: L10n.zoneSantaMariaMaggiore,
            center: CLLocationCoordinate2D(latitude: 46.0651, longitude: 11.1198),
            checkpointCount: 2
        ),
        Zone(
            id: "piazzaVenezia",
            name: L10n.zonePiazzaVenezia,
            center: CLLocationCoordinate2D(latitude: 46.0623, longitude: 11.1241),
            checkpointCount: 3
        )
    ]

    static let trentoCenter = CLLocationCoordinate2D(latitude: 46.0667, longitude: 11.1212)
}
