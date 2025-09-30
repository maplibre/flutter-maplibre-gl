import Foundation
import MapLibre

public class MapLibreCustomHeaders {
    private static var customHeaders: [String: String] = [:]
    private static var filterPatterns: [String] = []

    public static func setCustomHeaders(_ headers: [String: String], filter: [String]) {
        customHeaders = headers
        filterPatterns = filter

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpAdditionalHeaders = headers
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = sessionConfig
    }

    public static func getCustomHeaders() -> [String: String] {
        return customHeaders
    }

    public static func getFilterPatterns() -> [String] {
        return filterPatterns
    }

    public static func shouldApplyHeaders(to url: String) -> Bool {
        if filterPatterns.isEmpty {
            return true
        }

        for pattern in filterPatterns {
            if url.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }
}

