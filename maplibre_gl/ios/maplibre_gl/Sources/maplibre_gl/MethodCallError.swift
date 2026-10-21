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
    /// GeoJSON that MapLibre cannot read, or that is not what the call takes.
    case invalidGeoJson(message: String)
    case sourceNotFound(sourceId: String)
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
        case .invalidGeoJson:
            return "INVALID_GEOJSON"
        case .sourceNotFound:
            return "SOURCE_NOT_FOUND"
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
        case let .invalidGeoJson(message):
            return message
        case let .sourceNotFound(sourceId):
            return "Source '\(sourceId)' does not exist in the current style."
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
        case let .layerNotFound(layerId):
            return "Layer with id \(layerId) not found."
        case let .sourceAlreadyExists(sourceId):
            return "Source with id \(sourceId) already exists."
        case let .layerAlreadyExists(layerId):
            return "Layer with id \(layerId) already exists."
        case .unsupportedSourceType, .invalidArgument, .invalidGeoJson, .sourceNotFound,
             .styleNotReady:
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
