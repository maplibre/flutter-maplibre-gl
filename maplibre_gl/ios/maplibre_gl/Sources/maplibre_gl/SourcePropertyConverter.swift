import Foundation
import MapLibre

class SourcePropertyConverter {
    /// The options of a source with tiles, or nil for bounds or zoom levels
    /// MapLibre rejects. MapLibre raises an exception the call cannot catch
    /// for them, so they are checked here, as on Android.
    class func interpretTileOptions(properties: [String: Any]) -> [MLNTileSourceOption: Any]? {
        var options = [MLNTileSourceOption: Any]()

        if let bounds = properties["bounds"] {
            guard let coordinateBounds = tileBounds(bounds) else { return nil }
            options[.coordinateBounds] = NSValue(mlnCoordinateBounds: coordinateBounds)
        }
        var minzoom: Double?
        if let value = properties["minzoom"] {
            guard let zoom = tileZoom(value) else { return nil }
            minzoom = zoom
            options[.minimumZoomLevel] = zoom
        }
        if let value = properties["maxzoom"] {
            guard let zoom = tileZoom(value) else { return nil }
            if let minzoom = minzoom, minzoom > zoom { return nil }
            options[.maximumZoomLevel] = zoom
        }
        if let tileSize = properties["tileSize"] as? Double {
            options[.tileSize] = Int(tileSize)
        }
        if let scheme = properties["scheme"] as? String {
            let system: MLNTileCoordinateSystem = (scheme == "tms" ? .TMS : .XYZ)
            options[.tileCoordinateSystem] = system.rawValue
        }
        if let attribution = properties["attribution"] as? String {
            options[.attributionInfos] = parseAttributionHTML(attribution)
        }
        return options
    }
    
    /// The bounds of a tile source, [west, south, east, north], as MapLibre
    /// reads them on Android: the latitudes clamped to the poles and the
    /// longitudes to the antimeridian. Nil unless they are four finite numbers
    /// with south not above north and west not east of east.
    class func tileBounds(_ bounds: Any) -> MLNCoordinateBounds? {
        guard let values = bounds as? [Any], values.count == 4 else { return nil }
        let numbers = values.compactMap { number($0)?.doubleValue }.filter { $0.isFinite }
        guard numbers.count == 4 else { return nil }
        let south = min(max(numbers[1], -90), 90)
        let north = min(max(numbers[3], -90), 90)
        guard south <= north, numbers[0] <= numbers[2] else { return nil }
        return MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: south, longitude: max(numbers[0], -180)),
            ne: CLLocationCoordinate2D(latitude: north, longitude: min(numbers[2], 180))
        )
    }

    /// A zoom level of a tile source: a number from 0 to 255, the range
    /// MapLibre takes, or nil.
    class func tileZoom(_ value: Any) -> Double? {
        guard let zoom = number(value)?.doubleValue, zoom >= 0, zoom <= 255 else { return nil }
        return zoom
    }

    /// `text` as a URL the way Android reads one with `java.net.URI`: nil when
    /// it is empty or holds a character a URL cannot, such as a space, on
    /// every iOS version. iOS 17 and later would encode that character.
    class func strictURL(_ text: String) -> URL? {
        guard !text.isEmpty else { return nil }
        if #available(iOS 17.0, *) {
            return URL(string: text, encodingInvalidCharacters: false)
        }
        return URL(string: text)
    }

    class func parseAttributionHTML(_ html: String) -> [MLNAttributionInfo] {
        // Parse HTML attribution string and create a single attributed string with clickable links
        let pattern = #"<a\s+href=[\"']([^\"']+)[\"'][^>]*>([^<]+)</a>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            // Regex failed, use plain text
            let title = NSAttributedString(string: html)
            return [MLNAttributionInfo(title: title, url: nil)]
        }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if matches.isEmpty {
            // No links found, create simple attribution
            let title = NSAttributedString(string: html)
            return [MLNAttributionInfo(title: title, url: nil)]
        }
        
        // Build a single attributed string with all text and apply link attributes
        let attributedString = NSMutableAttributedString()
        var lastLocation = 0
        var primaryURL: URL?
        
        for match in matches {
            // Add text before the link
            if match.range.location > lastLocation {
                let plainRange = NSRange(location: lastLocation, length: match.range.location - lastLocation)
                let plainText = nsString.substring(with: plainRange)
                attributedString.append(NSAttributedString(string: plainText))
            }
            
            // Add the link text with link attribute
            if match.numberOfRanges >= 3 {
                let urlRange = match.range(at: 1)
                let textRange = match.range(at: 2)
                
                let urlString = nsString.substring(with: urlRange)
                let linkText = nsString.substring(with: textRange)
                
                if let url = URL(string: urlString) {
                    if primaryURL == nil {
                        primaryURL = url
                    }
                    let linkAttributedString = NSMutableAttributedString(string: linkText)
                    linkAttributedString.addAttribute(.link, value: url, range: NSRange(location: 0, length: linkText.count))
                    attributedString.append(linkAttributedString)
                }
            }
            
            lastLocation = match.range.location + match.range.length
        }
        
        // Add any remaining text after the last link
        if lastLocation < nsString.length {
            let remainingText = nsString.substring(from: lastLocation)
            attributedString.append(NSAttributedString(string: remainingText))
        }
        
        return [MLNAttributionInfo(title: attributedString, url: primaryURL)]
    }

    class func buildRasterTileSource(identifier: String,
                                     properties: [String: Any]) -> MLNRasterTileSource?
    {
        if let rawUrl = properties["url"] as? String, let url = URL(string: rawUrl) {
            return MLNRasterTileSource(identifier: identifier, configurationURL: url)
        }
        if let tiles = properties["tiles"] as? [String] {
            guard let options = interpretTileOptions(properties: properties) else { return nil }
            return MLNRasterTileSource(
                identifier: identifier,
                tileURLTemplates: tiles,
                options: options
            )
        }
        return nil
    }

    class func buildVectorTileSource(identifier: String,
                                     properties: [String: Any]) -> MLNVectorTileSource?
    {
        if let rawUrl = properties["url"] as? String, let url = URL(string: rawUrl) {
            return MLNVectorTileSource(identifier: identifier, configurationURL: url)
        }
        if let tiles = properties["tiles"] as? [String] {
            guard let options = interpretTileOptions(properties: properties) else { return nil }
            return MLNVectorTileSource(
                identifier: identifier,
                tileURLTemplates: tiles,
                options: options
            )
        }
        return nil
    }

    class func buildRasterDemSource(identifier: String,
                                    properties: [String: Any]) -> MLNRasterDEMSource?
    {
        if let rawUrl = properties["url"] as? String, let url = strictURL(rawUrl) {
            return MLNRasterDEMSource(identifier: identifier, configurationURL: url)
        }
        if let tiles = properties["tiles"] as? [String] {
            guard var options = interpretTileOptions(properties: properties) else { return nil }
            if let encoding = properties["encoding"] as? String {
                // MLNDEMEncoding knows only the two encodings below ("custom" is web
                // only and rejected before this). Any other fails addSource with
                // INVALID_ARGUMENT rather than drawing wrong elevations with the default.
                // The encoding is caller input, so it goes through %@, not the format string.
                switch encoding {
                case "terrarium":
                    options[.demEncoding] = NSNumber(value: MLNDEMEncoding.terrarium.rawValue)
                case "mapbox":
                    options[.demEncoding] = NSNumber(value: MLNDEMEncoding.mapbox.rawValue)
                default:
                    NSLog("%@", "maplibre_gl: unsupported raster-dem encoding '\(encoding)'")
                    return nil
                }
            }
            return MLNRasterDEMSource(
                identifier: identifier,
                tileURLTemplates: tiles,
                options: options
            )
        }
        return nil
    }

    class func interpretShapeOptions(properties: [String: Any]) -> [MLNShapeSourceOption: Any] {
        var options = [MLNShapeSourceOption: Any]()

        if let maxzoom = properties["maxzoom"] as? Double {
            options[.maximumZoomLevel] = maxzoom
        }

        if let buffer = properties["buffer"] as? Double {
            options[.buffer] = buffer
        }
        if let tolerance = properties["tolerance"] as? Double {
            options[.simplificationTolerance] = tolerance
        }

        if let cluster = properties["cluster"] as? Bool {
            options[.clustered] = cluster
        }
        if let clusterRadius = properties["clusterRadius"] as? Double {
            options[.clusterRadius] = clusterRadius
        }
        if let clusterMaxZoom = properties["clusterMaxZoom"] as? Double {
            options[.maximumZoomLevelForClustering] = clusterMaxZoom
        }
        if let clusterMinPoints = properties["clusterMinPoints"] as? Double {
            options[.clusterMinPoints] = clusterMinPoints
        }

        if let clusterProperties = properties["clusterProperties"] as? [String: Any] {
            var clusterPropertiesDict = [String: [NSExpression]]()
            for (propertyName, value) in clusterProperties {
                if let expressions = value as? [Any], expressions.count >= 2 {
                    let operatorValue = expressions[0]
                    let mapExpressionValue = expressions[1]

                    // The operator can be either:
                    // 1. A simple string like "+": expand to ["+", ["accumulated"], ["get", propertyName]]
                    // 2. A full reduce expression array like ["+", ["accumulated"], ["get", "sum"]]
                    let operatorJSON: Any
                    if let op = operatorValue as? String {
                        operatorJSON = [op, ["accumulated"], ["get", propertyName]]
                    } else {
                        operatorJSON = operatorValue
                    }

                    let operatorExpr = NSExpression(mglJSONObject: operatorJSON)
                    let mapExpr = NSExpression(mglJSONObject: mapExpressionValue)
                    clusterPropertiesDict[propertyName] = [operatorExpr, mapExpr]
                }
            }
            if !clusterPropertiesDict.isEmpty {
                options[.clusterProperties] = clusterPropertiesDict
            }
        }

        if let lineMetrics = properties["lineMetrics"] as? Bool {
            options[.lineDistanceMetrics] = lineMetrics
        }
        return options
    }

    /// The GeoJSON source `properties` describe: from the url its data names,
    /// or from the GeoJSON object it holds. Nil for a url Android cannot read
    /// either, such as an empty one, and for data that is not a JSON object.
    class func buildShapeSource(identifier: String, properties: [String: Any]) -> MLNShapeSource? {
        let options = interpretShapeOptions(properties: properties)
        guard let data = properties["data"] else { return nil }
        if let text = data as? String {
            guard let url = strictURL(text) else { return nil }
            return MLNShapeSource(identifier: identifier, url: url, options: options)
        }
        // JSONSerialization raises an exception the call cannot catch for
        // anything else.
        guard JSONSerialization.isValidJSONObject(data),
              let geoJsonData = try? JSONSerialization.data(withJSONObject: data),
              let shape = try? MLNShape(data: geoJsonData, encoding: String.Encoding.utf8.rawValue)
        else {
            return nil
        }
        return MLNShapeSource(identifier: identifier, shape: shape, options: options)
    }

    /// Whether `properties` give an image source a url and four [lng, lat]
    /// corners. quadFromArray and MapLibre would crash on bad corners.
    class func isImageSource(_ properties: [String: Any]) -> Bool {
        guard let url = properties["url"] as? String, !url.isEmpty,
              let corners = properties["coordinates"] as? [Any], corners.count == 4
        else {
            return false
        }
        for corner in corners {
            guard let pair = corner as? [Any], pair.count == 2,
                  let longitude = number(pair[0]), let latitude = number(pair[1]),
                  longitude.doubleValue.isFinite,
                  latitude.doubleValue >= -90, latitude.doubleValue <= 90
            else {
                return false
            }
        }
        return true
    }

    /// `value` as a number, or nil. The channel hands booleans over as
    /// NSNumbers too.
    private class func number(_ value: Any) -> NSNumber? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID()
        else {
            return nil
        }
        return number
    }

    class func buildImageSource(identifier: String, properties: [String: Any]) -> MLNImageSource? {
        if let rawUrl = properties["url"] as? String, let url = strictURL(rawUrl),
           let coordinates = properties["coordinates"] as? [[Double]]
        {
            return MLNImageSource(
                identifier: identifier,
                coordinateQuad: quadFromArray(coordinates: coordinates),
                url: url
            )
        }
        return nil
    }

    class func quadFromArray(coordinates: [[Double]]) -> MLNCoordinateQuad {
        return MLNCoordinateQuad(
            topLeft: CLLocationCoordinate2D(
                latitude: coordinates[0][1],
                longitude: coordinates[0][0]
            ),
            bottomLeft: CLLocationCoordinate2D(
                latitude: coordinates[3][1],
                longitude: coordinates[3][0]
            ),
            bottomRight: CLLocationCoordinate2D(
                latitude: coordinates[2][1],
                longitude: coordinates[2][0]
            ),
            topRight: CLLocationCoordinate2D(
                latitude: coordinates[1][1],
                longitude: coordinates[1][0]
            )
        )
    }
}
