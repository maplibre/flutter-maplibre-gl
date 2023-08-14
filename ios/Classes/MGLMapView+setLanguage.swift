//
//  MLNMapView+setLanguage.swift
//  maplibre_gl
//
//  Created by Julian Bissekkou on 09.08.23.
//

import Foundation
import Mapbox

extension MGLMapView {
    func setMapLanguage(_ language: String) {
        guard let style = style else { return }
        
        let layers = style.layers
        
        for layer in layers {
            if let symbolLayer = layer as? MGLSymbolStyleLayer {
                if symbolLayer.text == nil {
                    continue
                }
                 
                // We could skip the current iteration, whenever there is not current language.
                if !symbolLayer.text.description.containsLanguage() {
                    continue
                }
                
                let properties = ["text-field": "[\"coalesce\",[\"get\",\"name:\(language)\"],[\"get\",\"name:latin\"],[\"get\",\"name\"]]"]
                    
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
