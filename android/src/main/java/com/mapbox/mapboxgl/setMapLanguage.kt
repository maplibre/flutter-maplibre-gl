@file:JvmName("MapboxMapUtils")

package com.mapbox.mapboxgl

import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.style.expressions.Expression
import com.mapbox.mapboxsdk.style.layers.PropertyFactory
import com.mapbox.mapboxsdk.style.layers.SymbolLayer

fun MapboxMap.setMapLanguage(language: String) {
    val layers = this.style?.layers ?: emptyList()

    val languageRegex = Regex("(name:[a-z]+)")

    val symbolLayers = layers.filterIsInstance<SymbolLayer>()

    for (layer in symbolLayers) {
        // continue when there is no current expression
        val expression = layer.textField.expression ?: continue

        // We could skip the current iteration, whenever there is not current language.
        if (!expression.toString().contains(languageRegex)) {
            continue
        }

        val properties =
            "[\"coalesce\", [\"get\",\"name:$language\"],[\"get\",\"name:latin\"],[\"get\",\"name\"]]"

        layer.setProperties(PropertyFactory.textField(Expression.raw(properties)))
    }
}
