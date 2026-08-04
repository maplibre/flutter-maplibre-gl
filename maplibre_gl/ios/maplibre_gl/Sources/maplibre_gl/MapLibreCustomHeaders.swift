import Foundation
import MapLibre

public class MapLibreCustomHeaders {
    private static let queue = DispatchQueue(
        label: "io.flutter.maplibre_gl.customHeaders",
        attributes: .concurrent
    )
    private static var _customHeaders: [String: String] = [:]
    private static var _filterPatterns: [String] = []

    // Sets both headers and filter atomically.
    public static func setCustomHeaders(_ headers: [String: String], filter: [String]) {
        queue.async(flags: .barrier) {
            _customHeaders = headers
            _filterPatterns = filter
        }
    }

    // Updates only headers, leaving the existing filter intact.
    public static func setHeaders(_ headers: [String: String]) {
        queue.async(flags: .barrier) {
            _customHeaders = headers
        }
    }

    public static func getCustomHeaders() -> [String: String] {
        queue.sync { _customHeaders }
    }

    public static func getFilterPatterns() -> [String] {
        queue.sync { _filterPatterns }
    }

    // Returns headers and whether they should be applied, in a single lock acquisition.
    public static func headersIfApplicable(to url: String) -> (headers: [String: String], apply: Bool) {
        queue.sync {
            let apply: Bool
            if _filterPatterns.isEmpty {
                apply = true
            } else {
                apply = _filterPatterns.contains {
                    url.range(of: $0, options: .regularExpression) != nil
                }
            }
            return (_customHeaders, apply)
        }
    }

    public static func shouldApplyHeaders(to url: String) -> Bool {
        headersIfApplicable(to: url).apply
    }
}
