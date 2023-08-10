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
                
                if symbolLayer.text.description.contains("ref") {
                    continue
                }
                
                let properties = ["text-field": "[\"coalesce\", [\"get\",\"name:\(language)\"],[\"get\",\"name:latin\"]]"]
                    
                LayerPropertyConverter.addSymbolProperties(
                    symbolLayer: symbolLayer,
                    properties: properties
                )
            }
        }
    }
}
