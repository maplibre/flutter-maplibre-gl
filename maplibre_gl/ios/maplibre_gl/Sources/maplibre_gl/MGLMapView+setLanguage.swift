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
        
        let layers = style.layers
        
        for layer in layers {
            if let symbolLayer = layer as? MLNSymbolStyleLayer {
                if symbolLayer.text == nil {
                    continue
                }
                 
                // We could skip the current iteration, whenever there is not current language.
                if !symbolLayer.text.description.containsLanguage() {
                    continue
                }
                
                // Pass the text-field expression as a native NSArray, not a
                // JSON-encoded string. LayerPropertyConverter.interpretExpression
                // documents its contract as "The value is already in native
                // format (not JSON string), use it directly" — a JSON string
                // falls through to NSExpression(mglJSONObject:) which treats
                // it as a constant string value, so every affected label
                // renders as literal '[COALESCE], [GET: name:xx], ...' text
                // on iOS (Android is unaffected because its converter takes
                // a different path). Reported as the same root cause behind
                // issues #250 and #336.
                let expression: [Any] = [
                    "coalesce",
                    ["get", "name:\(language)"],
                    ["get", "name:latin"],
                    ["get", "name"],
                ]
                let properties: [String: Any] = ["text-field": expression]

                LayerPropertyConverter.addSymbolProperties(
                    symbolLayer: symbolLayer,
                    properties: properties
                )
            }
        }
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
