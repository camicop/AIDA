import CoreLocation

struct MissionArea {
    let center: CLLocationCoordinate2D
    let radiusMeters: Double
    let nearestZoneName: LocalizedString?

    var diameterMeters: Double { radiusMeters * 2 }

    var displayName: LocalizedString {
        let diameterText = String(format: "%.1f km", diameterMeters / 1000)
        if let name = nearestZoneName {
            return LocalizedString(
                it: "\(name.it) · \(diameterText)",
                en: "\(name.en) · \(diameterText)"
            )
        }
        return LocalizedString(it: diameterText, en: diameterText)
    }

    static func nearestZoneName(to coordinate: CLLocationCoordinate2D,
                                within meters: Double,
                                in zones: [Zone]) -> LocalizedString? {
        let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearest = zones.min { lhs, rhs in
            CLLocation(latitude: lhs.center.latitude, longitude: lhs.center.longitude).distance(from: centerLocation)
            <
            CLLocation(latitude: rhs.center.latitude, longitude: rhs.center.longitude).distance(from: centerLocation)
        }
        guard let nearest else { return nil }
        let distance = CLLocation(latitude: nearest.center.latitude, longitude: nearest.center.longitude)
            .distance(from: centerLocation)
        return distance <= meters ? nearest.name : nil
    }
}
