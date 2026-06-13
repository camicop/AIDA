import UIKit
import MapKit
import CoreLocation

/// Renders a static 16:9 map image with a target marker, for embedding in a chat
/// bubble. No live map view — just a snapshot.
enum MapSnapshotRenderer {
    private static let size = CGSize(width: 320, height: 180)

    /// Produces a snapshot centered on `center` with a purple circle at a point
    /// `distanceMeters` away along `bearingDegrees` (0 = north) and a blue dot at
    /// the center (the user). Completion is always called on the main actor.
    @MainActor
    static func render(center: CLLocationCoordinate2D,
                       bearingDegrees: Double,
                       distanceMeters: Double,
                       completion: @escaping (UIImage?) -> Void) {
        let target = coordinate(from: center, distanceMeters: distanceMeters, bearingDegrees: bearingDegrees)

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: max(distanceMeters * 4, 400),
            longitudinalMeters: max(distanceMeters * 4, 400)
        )
        options.size = size

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: .main) { snapshot, _ in
            guard let snapshot else {
                completion(nil)
                return
            }
            let image = draw(snapshot: snapshot, userCenter: center, target: target)
            completion(image)
        }
    }

    private static func draw(snapshot: MKMapSnapshotter.Snapshot,
                             userCenter: CLLocationCoordinate2D,
                             target: CLLocationCoordinate2D) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            let userPoint = snapshot.point(for: userCenter)
            let targetPoint = snapshot.point(for: target)

            // Target: purple translucent circle with a solid ring.
            let radius: CGFloat = 16
            let targetRect = CGRect(x: targetPoint.x - radius, y: targetPoint.y - radius,
                                    width: radius * 2, height: radius * 2)
            UIColor.systemPurple.withAlphaComponent(0.25).setFill()
            context.cgContext.fillEllipse(in: targetRect)
            UIColor.systemPurple.setStroke()
            context.cgContext.setLineWidth(3)
            context.cgContext.strokeEllipse(in: targetRect)

            // User: small solid blue dot with a white outline.
            let dot: CGFloat = 7
            let dotRect = CGRect(x: userPoint.x - dot, y: userPoint.y - dot,
                                 width: dot * 2, height: dot * 2)
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(2)
            UIColor.systemBlue.setFill()
            context.cgContext.fillEllipse(in: dotRect)
            context.cgContext.strokeEllipse(in: dotRect)
        }
    }

    private static func coordinate(from origin: CLLocationCoordinate2D,
                                   distanceMeters: Double,
                                   bearingDegrees: Double) -> CLLocationCoordinate2D {
        let metersPerDegreeLat = 111_320.0
        let bearing = bearingDegrees * .pi / 180
        let deltaLat = (distanceMeters * cos(bearing)) / metersPerDegreeLat
        let metersPerDegreeLon = metersPerDegreeLat * cos(origin.latitude * .pi / 180)
        let deltaLon = (distanceMeters * sin(bearing)) / metersPerDegreeLon
        return CLLocationCoordinate2D(latitude: origin.latitude + deltaLat,
                                      longitude: origin.longitude + deltaLon)
    }
}
