//
//  OfflineRegionData.swift
//  location
//
//  Created by Patryk on 02/06/2020.
//

import Foundation
import MapLibre

class OfflineRegion {
    let id: Int
    let metadata: [String: Any]
    let definition: OfflineRegionDefinition

    enum CodingKeys: CodingKey {
        case id, metadata, definition
    }

    init(id: Int, metadata: [String: Any], definition: OfflineRegionDefinition) {
        self.id = id
        self.metadata = metadata
        self.definition = definition
    }

    /// The pack context: the ID and the metadata as JSON. Metadata that is not
    /// JSON is left out, since JSONSerialization would raise an NSException,
    /// which Swift cannot catch; callers reject it before they get here.
    func prepareContext() -> Data {
        let context: [String: Any] = [
            "metadata": JSONSerialization.isValidJSONObject(metadata) ? metadata : [:],
            "id": id,
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: context, options: [])
        return jsonData ?? Data()
    }

    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "metadata": metadata,
            "definition": definition.toDictionary(),
        ]
    }

    static func fromOfflinePack(_ pack: MLNOfflinePack) -> OfflineRegion? {
        guard let region = pack.region as? MLNTilePyramidOfflineRegion,
              let dataObject = try? JSONSerialization.jsonObject(with: pack.context, options: []),
              let dict = dataObject as? [String: Any],
              let id = dict["id"] as? Int else { return nil }
        return OfflineRegion(
            id: id,
            // Unreadable metadata reads as empty, as on Android, rather than
            // hiding the region.
            metadata: dict["metadata"] as? [String: Any] ?? [:],
            definition: OfflineRegionDefinition(
                bounds: [region.bounds.sw, region.bounds.ne].map { [$0.latitude, $0.longitude] },
                mapStyleUrl: region.styleURL,
                minZoom: region.minimumZoomLevel,
                maxZoom: region.maximumZoomLevel
            )
        )
    }
}
