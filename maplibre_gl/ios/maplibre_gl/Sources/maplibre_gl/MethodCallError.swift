import Flutter

/// The errors the style, source and layer calls fail with. Codes and messages
/// are the ones Android and web answer for the same case.
enum MethodCallError: Error {
    case invalidLayerType(details: String)
    /// A source whose type the call cannot work with.
    case unsupportedSourceType(message: String)
    /// An argument the call cannot use, with what is wrong with it.
    case invalidArgument(message: String)
    /// A filter that is not JSON or that the engine rejected, with why.
    case invalidFilter(reason: String)
    /// A layer property value the engine rejected: INVALID_EXPRESSION for an
    /// expression, INVALID_ARGUMENT for any other value.
    case invalidLayerProperty(layerId: String, property: String, isExpression: Bool, reason: String)
    /// GeoJSON that MapLibre cannot read, or that is not what the call takes.
    case invalidGeoJson(message: String)
    case sourceNotFound(sourceId: String)
    /// A layer on a vector source that names no source layer.
    case sourceLayerRequired(layerId: String, sourceId: String)
    case layerNotFound(layerId: String)
    /// A call that needs a style while none is loaded.
    case styleNotReady
    case sourceAlreadyExists(sourceId: String)
    case layerAlreadyExists(layerId: String)

    var code: String {
        switch self {
        case .invalidLayerType:
            return "INVALID_LAYER_TYPE"
        case .unsupportedSourceType:
            return "UNSUPPORTED_SOURCE_TYPE"
        case .invalidArgument:
            return "INVALID_ARGUMENT"
        case .invalidFilter:
            return "INVALID_EXPRESSION"
        case let .invalidLayerProperty(_, _, isExpression, _):
            return isExpression ? "INVALID_EXPRESSION" : "INVALID_ARGUMENT"
        case .invalidGeoJson:
            return "INVALID_GEOJSON"
        case .sourceNotFound:
            return "SOURCE_NOT_FOUND"
        case .sourceLayerRequired:
            return "SOURCE_LAYER_REQUIRED"
        case .layerNotFound:
            return "LAYER_NOT_FOUND_ERROR"
        case .styleNotReady:
            return "STYLE_NOT_READY"
        case .sourceAlreadyExists:
            return "SOURCE_ALREADY_EXISTS"
        case .layerAlreadyExists:
            return "LAYER_ALREADY_EXISTS"
        }
    }

    var message: String {
        switch self {
        case .invalidLayerType:
            return "Invalid layer type"
        case let .unsupportedSourceType(message):
            return message
        case let .invalidArgument(message):
            return message
        case let .invalidFilter(reason):
            return "Invalid filter: \(reason)"
        case let .invalidLayerProperty(layerId, property, isExpression, reason):
            return "\(isExpression ? "Invalid expression" : "Invalid value") for property "
                + "'\(property)' of layer '\(layerId)': \(reason)"
        case let .invalidGeoJson(message):
            return message
        case let .sourceNotFound(sourceId):
            return "Source '\(sourceId)' does not exist in the current style."
        case let .sourceLayerRequired(layerId, sourceId):
            return "Source '\(sourceId)' is a vector source, so layer '\(layerId)' requires a "
                + "'sourceLayer'."
        case .layerNotFound:
            return "Layer not found"
        case .styleNotReady:
            return "Style is null or not fully loaded. Has onStyleLoaded() already been invoked?"
        case .sourceAlreadyExists:
            return "Source already exists"
        case .layerAlreadyExists:
            return "Layer already exists"
        }
    }

    var details: String? {
        switch self {
        case let .invalidLayerType(details):
            return details
        case let .invalidFilter(reason):
            return reason
        case let .invalidLayerProperty(_, _, _, reason):
            return reason
        case let .layerNotFound(layerId):
            return "Layer with id \(layerId) not found."
        case let .sourceAlreadyExists(sourceId):
            return "Source with id \(sourceId) already exists."
        case let .layerAlreadyExists(layerId):
            return "Layer with id \(layerId) already exists."
        case .unsupportedSourceType, .invalidArgument, .invalidGeoJson, .sourceNotFound,
             .sourceLayerRequired, .styleNotReady:
            return nil
        }
    }

    var flutterError: FlutterError {
        return FlutterError(
            code: code,
            message: message,
            details: details
        )
    }
}

// The messages shared with Android and web.
extension MethodCallError {
    /// A coordinate that is NaN or infinite, which MapLibre cannot place.
    static let nonFiniteCoordinates = "Latitude and longitude must be finite numbers."

    /// A latitude beyond the poles.
    static let latitudeOutOfRange = "Latitude must be within -90 and 90."

    /// A screen point that is NaN or infinite.
    static let nonFiniteScreenPoint = "Screen coordinates must be finite numbers."

    /// A camera update with a zoom, angle, offset or padding that is not finite.
    static let nonFiniteCameraValues =
        "Zoom, bearing, tilt, offsets and padding must be finite numbers."

    /// A source the properties it was given cannot build.
    static func unbuildableSource(sourceId: String, type: String) -> MethodCallError {
        return .invalidArgument(
            message: "Source '\(sourceId)' cannot be built from its properties as a '\(type)' "
                + "source."
        )
    }

    /// A call made on a source that is not GeoJSON. `methodName` is the Dart
    /// method, and `clustered` tells whether it needs a clustered source.
    static func notGeoJsonSource(
        sourceId: String,
        methodName: String,
        clustered: Bool = false
    ) -> MethodCallError {
        return .unsupportedSourceType(
            message: "Source '\(sourceId)' is not a GeoJSON source. \(methodName) only applies "
                + "to \(clustered ? "clustered " : "")GeoJSON sources."
        )
    }

    /// A camera padding that does not fit in the 32 bits Android takes.
    static func paddingOutOfRange(_ padding: Int64) -> MethodCallError {
        return .invalidArgument(message: "Padding \(padding) does not fit in 32 bits.")
    }
}
