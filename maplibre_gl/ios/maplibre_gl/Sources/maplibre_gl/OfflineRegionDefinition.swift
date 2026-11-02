import Foundation
import MapLibre

class OfflineRegionDefinition {
    let bounds: [[Double]]
    let mapStyleUrl: URL
    let minZoom: Double
    let maxZoom: Double
    let includeIdeographs: Bool

    init(
        bounds: [[Double]],
        mapStyleUrl: URL,
        minZoom: Double,
        maxZoom: Double,
        includeIdeographs: Bool
    ) {
        self.bounds = bounds
        self.mapStyleUrl = mapStyleUrl
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.includeIdeographs = includeIdeographs
    }

    /// The definition of a stored region.
    convenience init(region: MLNTilePyramidOfflineRegion) {
        self.init(
            bounds: [region.bounds.sw, region.bounds.ne].map { [$0.latitude, $0.longitude] },
            mapStyleUrl: region.styleURL,
            minZoom: region.minimumZoomLevel,
            maxZoom: region.maximumZoomLevel,
            includeIdeographs: region.includesIdeographicGlyphs
        )
    }

    func getBounds() -> MLNCoordinateBounds {
        return MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: bounds[0][0], longitude: bounds[0][1]),
            ne: CLLocationCoordinate2D(latitude: bounds[1][0], longitude: bounds[1][1])
        )
    }

    static func fromDictionary(_ jsonDict: [String: Any]) -> OfflineRegionDefinition? {
        guard let bounds = jsonDict["bounds"] as? [[Double]],
              let mapStyleUrlString = jsonDict["mapStyleUrl"] as? String,
              let mapStyleUrl = URL(string: mapStyleUrlString),
              let minZoom = jsonDict["minZoom"] as? Double,
              let maxZoom = jsonDict["maxZoom"] as? Double
        else { return nil }
        return OfflineRegionDefinition(
            bounds: bounds,
            mapStyleUrl: mapStyleUrl,
            minZoom: minZoom,
            maxZoom: maxZoom,
            includeIdeographs: jsonDict["includeIdeographs"] as? Bool ?? false
        )
    }

    func toDictionary() -> [String: Any] {
        return [
            "bounds": bounds,
            "mapStyleUrl": mapStyleUrl.absoluteString,
            "minZoom": minZoom,
            "maxZoom": maxZoom,
            "includeIdeographs": includeIdeographs,
        ]
    }

    func toMLNTilePyramidOfflineRegion() -> MLNTilePyramidOfflineRegion {
        let region = MLNTilePyramidOfflineRegion(
            styleURL: mapStyleUrl,
            bounds: getBounds(),
            fromZoomLevel: minZoom,
            toZoomLevel: maxZoom
        )
        region.includesIdeographicGlyphs = includeIdeographs
        return region
    }
}
