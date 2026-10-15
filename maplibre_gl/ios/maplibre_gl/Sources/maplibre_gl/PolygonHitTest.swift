import CoreLocation
import MapLibre

/*
 *  Tells whether a polygon returned by a visible-features query around a touch is really under
 *  the finger. MapLibre Native tests each ring of a polygon on its own (upstream, in
 *  polygonIntersectsMultiPolygon), so a box inside a hole still finds the polygon through its
 *  outer ring (#893). MapLibre GL JS, on web, counts all rings together and skips the hole; this
 *  check does the same for taps and drags. Android has the same math in PolygonHitTest.java:
 *  keep them in step. Remove both once maplibre/maplibre-native#4783 is fixed in the SDK we
 *  ship.
 *
 *  The math runs in Web Mercator world coordinates at the camera zoom. MapLibre tiles are 512
 *  points wide, so one unit there is one point on screen and ring edges compare directly with
 *  the touch tolerance, with no projection call per vertex. Bearing does not change distances.
 *  With pitch the scale varies across the screen, so the tolerance is approximate there.
 */
struct PolygonHitTest {
    private static let maxLatitude = 85.0511287798066

    private let zoom: Double
    private let touch: (x: Double, y: Double)

    /// A touch at coordinate with the camera at zoom.
    init(touch coordinate: CLLocationCoordinate2D, zoom: Double) {
        self.zoom = zoom
        touch = PolygonHitTest.toWorld(coordinate, zoom: zoom)
    }

    /*
     *  Whether feature, returned for a square of half side radius points around the touch,
     *  counts as hit. Only a polygon whose hole holds the touch is checked again: it counts when
     *  one of its ring edges, outer or hole, is within radius. Anything else stays as MapLibre
     *  returned it: other geometries, a touch on the filled area, or one outside every ring,
     *  where the native query already measures to the edges.
     */
    func keeps(_ feature: MLNFeature, radius: Double) -> Bool {
        let rings = PolygonHitTest.rings(of: feature).map { ring in
            ring.map { PolygonHitTest.toWorld($0, zoom: zoom) }
        }
        if rings.isEmpty { return true }

        // Even-odd over all rings: an odd count is the filled area, zero is outside the polygon.
        let containing = rings.filter { contains($0) }.count
        if containing == 0 || containing % 2 == 1 { return true }

        // In a hole: hit only near its border, or the border of any other ring.
        let radiusSquared = radius * radius
        for ring in rings where !ring.isEmpty {
            var j = ring.count - 1
            for i in 0..<ring.count {
                if distanceSquared(ring[j], ring[i]) <= radiusSquared { return true }
                j = i
            }
        }
        return false
    }

    private static func rings(of feature: MLNFeature) -> [[CLLocationCoordinate2D]] {
        func coordinates(_ shape: MLNMultiPoint) -> [CLLocationCoordinate2D] {
            Array(UnsafeBufferPointer(start: shape.coordinates, count: Int(shape.pointCount)))
        }
        func polygonRings(_ polygon: MLNPolygon) -> [[CLLocationCoordinate2D]] {
            [coordinates(polygon)] + (polygon.interiorPolygons ?? []).flatMap { polygonRings($0) }
        }
        if let polygon = feature as? MLNPolygon {
            return polygonRings(polygon)
        }
        if let multiPolygon = feature as? MLNMultiPolygon {
            return multiPolygon.polygons.flatMap { polygonRings($0) }
        }
        return []
    }

    /// Web Mercator world coordinates, in points, of a coordinate at the camera zoom.
    private static func toWorld(
        _ coordinate: CLLocationCoordinate2D,
        zoom: Double
    ) -> (x: Double, y: Double) {
        let worldSize = 512 * pow(2, zoom)
        let latitude = max(-maxLatitude, min(maxLatitude, coordinate.latitude))
        let sine = sin(latitude * .pi / 180)
        let x = (coordinate.longitude + 180) / 360 * worldSize
        let y = (0.5 - log((1 + sine) / (1 - sine)) / (4 * .pi)) * worldSize
        return (x, y)
    }

    /// Crossing test of the touch against one ring.
    private func contains(_ ring: [(x: Double, y: Double)]) -> Bool {
        guard !ring.isEmpty else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let a = ring[i]
            let b = ring[j]
            if (a.y > touch.y) != (b.y > touch.y),
               touch.x < (b.x - a.x) * (touch.y - a.y) / (b.y - a.y) + a.x
            {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Squared distance from the touch to the segment from a to b.
    private func distanceSquared(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared == 0
            ? 0
            : max(0, min(1, ((touch.x - a.x) * dx + (touch.y - a.y) * dy) / lengthSquared))
        let ex = a.x + t * dx - touch.x
        let ey = a.y + t * dy - touch.y
        return ex * ex + ey * ey
    }
}
