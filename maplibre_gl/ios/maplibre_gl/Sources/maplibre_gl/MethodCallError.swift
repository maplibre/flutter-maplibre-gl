import Flutter

enum MethodCallError: Error {
    case genericError(details: String)
    case invalidLayerType(details: String)
    case invalidSourceType(details: String)
    case invalidExpression
    case sourceNotFound(sourceId: String)
    case layerNotFound(layerId: String)
    case styleNotFound
    case sourceAlreadyExists(sourceId: String)
    case layerAlreadyExists(layerId: String)
    case geojsonParseError(sourceId: String)

    var code: String {
        switch self {
        case .genericError:
            return "genericError"
        case .invalidLayerType:
            return "invalidLayerType"
        case .invalidSourceType:
            return "invalidSourceType"
        case .invalidExpression:
            return "invalidExpression"
        case .sourceNotFound:
            return "sourceNotFound"
        case .layerNotFound:
            return "layerNotFound"
        case .styleNotFound:
            return "styleNotFound"
        case .sourceAlreadyExists:
            return "sourceAlreadyExists"
        case .layerAlreadyExists:
            return "layerAlreadyExists"
        case .geojsonParseError:
            return "parseError"

        }
    }

    var message: String {
        switch self {
        case .genericError:
            return "Generic error"
        case .invalidLayerType:
            return "Invalid layer type"
        case .invalidSourceType:
            return "Invalid source type"
        case .invalidExpression:
            return "Invalid expression"
        case .sourceNotFound:
            return "Source not found"
        case .layerNotFound:
            return "Layer not found"
        case .styleNotFound:
            return "Style not found"
        case .sourceAlreadyExists:
            return "Source already exists"
        case .layerAlreadyExists:
            return "Layer already exists"
        case .geojsonParseError:
            return "Geojson parse error"
        }
    }

    var details: String {
        switch self {
        case let .genericError(details):
            return details
        case let .invalidLayerType(details):
            return details
        case let .invalidSourceType(details):
            return details
        case .invalidExpression:
            return "Could not parse expression."
        case let .sourceNotFound(sourceId):
            return "Source with id \(sourceId) not found."
        case let .layerNotFound(layerId):
            return "Layer with id \(layerId) not found."
        case .styleNotFound:
            return "Style not found."
        case let .sourceAlreadyExists(sourceId):
            return "Source with id \(sourceId) already exists."
        case let .layerAlreadyExists(layerId):
            return "Layer with id \(layerId) already exists."
        case let .geojsonParseError(sourceId):
            return "Geojson parse error for source with id \(sourceId)."
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
