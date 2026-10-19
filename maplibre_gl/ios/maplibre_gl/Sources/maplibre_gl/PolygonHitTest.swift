import CoreLocation
import MapLibre

/*
 *  Tells whether a polygon returned by a visible-features query around a touch is really under
 *  the finger. MapLibre Native tests each ring of a polygon on its own (upstream, in
 *  polygonIntersectsMultiPolygon), so a box inside a hole still finds the polygon through its
 *  outer ring (#893). MapLibre GL JS, on web, counts the rings of each polygon together and
 *  skips the hole; this check does the same for taps and drags. Android has the same math in
 *  PolygonHitTest.java, and PolygonHitTestTest.java holds the cases both must pass: keep them in
 *  step. Remove both once maplibre/maplibre-native#4783 is fixed in the SDK we ship.
 *
 *  The math runs in Web Mercator world coordinates at the camera zoom. MapLibre tiles are 512
 *  points wide, so one unit there is one point on screen and ring edges compare directly with
 *  the touch tolerance, with no projection call per vertex. Bearing does not change distances.
 *
 *  Known limits, where the result falls back to what MapLibre returns or is approximate:
 *  - With pitch the scale varies across the screen, so the tolerance is approximate there.
 *  - Features come back clipped to their tile. When a hole crosses a tile edge and the source
 *    has a small buffer, the clip line acts as a ring edge: a touch in the hole within the
 *    tolerance of that line counts as near the border, and the polygon is kept as MapLibre
 *    returned it.
 */
struct PolygonHitTest {
    private static let maxLatitude = 85.0511287798066

    private let worldSize: Double
    private let touch: (x: Double, y: Double)

    /// A touch at coordinate with the camera at zoom. The longitude is wrapped into [-180, 180),
    /// as a touch on another copy of the world comes back unwrapped while feature geometries do
    /// not.
    init(touch coordinate: CLLocationCoordinate2D, zoom: Double) {
        worldSize = 512 * pow(2, zoom)
        touch = PolygonHitTest.toWorld(
            longitude: PolygonHitTest.wrap(coordinate.longitude),
            latitude: coordinate.latitude,
            worldSize: worldSize
        )
    }

    /*
     *  Whether a geometry made of polygons, each a list of rings with the outer one first,
     *  counts as hit. Only a touch in a hole is checked again: it counts when one of the ring
     *  edges, outer or hole, is within radius. Anything else stays as MapLibre returned it:
     *  other geometries, polygons without holes, a touch on the filled area of any polygon, or
     *  one outside every ring, where the native query already measures to the edges.
     */
    func keeps(polygons: [[[CLLocationCoordinate2D]]], radius: Double) -> Bool {
        if !polygons.contains(where: { $0.count > 1 }) { return true }

        var projected: [[(x: Double, y: Double)]] = []
        var inHole = false
        for polygon in polygons {
            var containing = 0
            for ring in polygon {
                let world = ring.map {
                    PolygonHitTest.toWorld(
                        longitude: $0.longitude,
                        latitude: $0.latitude,
                        worldSize: worldSize
                    )
                }
                projected.append(world)
                if contains(world) { containing += 1 }
            }
            // Even-odd over the rings of one polygon: odd is its filled area, even and not zero
            // a hole.
            if containing % 2 == 1 { return true }
            if containing > 0 { inHole = true }
        }
        if !inHole { return true }

        // In a hole: hit only near its border, or the border of any other ring.
        let radiusSquared = radius * radius
        for ring in projected where !ring.isEmpty {
            var j = ring.count - 1
            for i in 0..<ring.count {
                if distanceSquared(ring[j], ring[i]) <= radiusSquared { return true }
                j = i
            }
        }
        return false
    }

    /// longitude in [-180, 180).
    private static func wrap(_ longitude: Double) -> Double {
        var shifted = (longitude + 180).truncatingRemainder(dividingBy: 360)
        if shifted < 0 { shifted += 360 }
        return shifted - 180
    }

    /// Web Mercator world coordinates, in points, of a coordinate at the camera zoom.
    private static func toWorld(
        longitude: Double,
        latitude: Double,
        worldSize: Double
    ) -> (x: Double, y: Double) {
        let clamped = max(-maxLatitude, min(maxLatitude, latitude))
        let sine = sin(clamped * .pi / 180)
        let x = (longitude + 180) / 360 * worldSize
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

// MARK: - MapLibre features

extension PolygonHitTest {
    /// Whether feature, returned for a square of half side radius points around the touch,
    /// counts as hit. See keeps(polygons:radius:).
    func keeps(_ feature: MLNFeature, radius: Double) -> Bool {
        keeps(polygons: PolygonHitTest.polygons(of: feature), radius: radius)
    }

    private static func polygons(of feature: MLNFeature) -> [[[CLLocationCoordinate2D]]] {
        func coordinates(_ shape: MLNMultiPoint) -> [CLLocationCoordinate2D] {
            Array(UnsafeBufferPointer(start: shape.coordinates, count: Int(shape.pointCount)))
        }
        func rings(_ polygon: MLNPolygon) -> [[CLLocationCoordinate2D]] {
            [coordinates(polygon)] + (polygon.interiorPolygons ?? []).flatMap { rings($0) }
        }
        if let polygon = feature as? MLNPolygon {
            return [rings(polygon)]
        }
        if let multiPolygon = feature as? MLNMultiPolygon {
            return multiPolygon.polygons.map { rings($0) }
        }
        return []
    }
}
