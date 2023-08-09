package com.mapbox.mapboxgl

import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.style.expressions.Expression
import com.mapbox.mapboxsdk.style.layers.PropertyFactory
import com.mapbox.mapboxsdk.style.layers.SymbolLayer

class MapLibreLocalization(private val mapBoxMap: MapboxMap) {

    fun setMapLanguage(language: String) {
        val layers = mapBoxMap.style?.layers ?: emptyList()

        val symbolLayers = layers.filterIsInstance<SymbolLayer>()

        for (layer in symbolLayers) {
            val expression = layer.textField.expression ?: continue

            val nameRegex = Regex("(name:[a-z]+)")

            val newExpression = expression
                .toString()
                .replace(nameRegex, "name:$language")

            layer.setProperties(PropertyFactory.textField(Expression.raw(newExpression)))
        }
    }
}