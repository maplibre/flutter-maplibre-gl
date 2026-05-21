//
//  MLNMapView+setLanguage.swift
//  maplibre_gl
//
//  Created by Julian Bissekkou on 09.08.23.
//

import Foundation
import MapLibre

extension MLNMapView {
    func setMapLanguage(_ language: String) {
        guard let style = style else { return }

        let properties = Self.textFieldExpressionProperties(for: language)

        for layer in style.layers {
            if let symbolLayer = layer as? MLNSymbolStyleLayer {
                if symbolLayer.text == nil {
                    continue
                }

                // We could skip the current iteration, whenever there is not current language.
                if !symbolLayer.text.description.containsLanguage() {
                    continue
                }

                LayerPropertyConverter.addSymbolProperties(
                    symbolLayer: symbolLayer,
                    properties: properties
                )
            }
        }
    }

    /// Builds the `text-field` properties dictionary handed to
    /// `LayerPropertyConverter.addSymbolProperties` by `setMapLanguage`.
    /// Extracted so the expression-building logic is readable in isolation
    /// (and can be exercised by future Swift unit tests via `@testable
    /// import maplibre_gl`).
    ///
    /// The value MUST be a native `NSArray`-compatible `[Any]`, not a
    /// JSON-encoded string. `interpretExpression` in
    /// `LayerPropertyConverter` documents its contract as "The value is
    /// already in native format (not JSON string), use it directly" — a
    /// JSON string falls through to `NSExpression(mglJSONObject:)`, which
    /// on a String argument constructs an expression for a constant string,
    /// so every affected symbol layer renders its label as the literal
    /// placeholder text `[COALESCE], [GET: name:xx], [GET: name:latin],
    /// [GET: name]`. Android is unaffected because its converter takes a
    /// different path. Same root cause as the still-unresolved bug in #250
    /// and the open report in #336.
    static func textFieldExpressionProperties(
        for language: String
    ) -> [String: Any] {
        let expression: [Any] = [
            "coalesce",
            ["get", "name:\(language)"],
            ["get", "name:latin"],
            ["get", "name"],
        ]
        return ["text-field": expression]
    }
}


private extension String {
    func containsLanguage() -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: "(name:[a-z]+)")
            let range = NSRange(location: 0, length: self.utf16.count)
            
            if let _ = regex.firstMatch(in: self, options: [], range: range) {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}
