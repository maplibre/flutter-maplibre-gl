package org.maplibre.maplibregl

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The checks of the layer and source calls, which answer what iOS and web answer. */
class StyleChecksTest {
    @Test
    fun aLayerDrawsTheTileItsSourceMakes() {
        for (layer in listOf("fill", "line", "symbol", "circle", "heatmap", "fill-extrusion")) {
            assertTrue(layer, StyleChecks.canDraw(layer, "geojson"))
            assertTrue(layer, StyleChecks.canDraw(layer, "vector"))
            assertFalse(layer, StyleChecks.canDraw(layer, "raster"))
            assertFalse(layer, StyleChecks.canDraw(layer, "image"))
            assertFalse(layer, StyleChecks.canDraw(layer, "raster-dem"))
        }
        assertTrue(StyleChecks.canDraw("raster", "raster"))
        assertTrue(StyleChecks.canDraw("raster", "image"))
        assertFalse(StyleChecks.canDraw("raster", "geojson"))
        assertFalse(StyleChecks.canDraw("raster", "raster-dem"))
        for (layer in listOf("hillshade", "color-relief")) {
            assertTrue(layer, StyleChecks.canDraw(layer, "raster-dem"))
            assertFalse(layer, StyleChecks.canDraw(layer, "raster"))
            assertFalse(layer, StyleChecks.canDraw(layer, "geojson"))
        }
    }

    @Test
    fun theMessagesAreTheOnesIosAndWebGive() {
        assertEquals(
            "Layer 'l' of type 'raster' cannot use source 's' of type 'geojson'.",
            StyleChecks.incompatibleSource("l", "raster", "s", "geojson"),
        )
        assertEquals(
            "Source 'v' is a video source. Video sources are only supported on web.",
            StyleChecks.videoSource("v"),
        )
    }

    @Test
    fun aRejectedValueIsAnExpressionWhenItStartsWithAnOperatorName() {
        val expression = listOf("no-such-operator", 1)
        assertEquals("INVALID_EXPRESSION", StyleChecks.invalidPropertyCode(expression))
        assertEquals(
            "Invalid expression for property 'circle-radius' of layer 'l': Unknown.",
            StyleChecks.invalidProperty("l", "circle-radius", expression, "Unknown."),
        )
        for (value in listOf("big", 5, true, emptyList<Any>(), listOf(1, 2), null)) {
            assertEquals("$value", "INVALID_ARGUMENT", StyleChecks.invalidPropertyCode(value))
        }
        assertEquals(
            "Invalid value for property 'circle-radius' of layer 'l': Why.",
            StyleChecks.invalidProperty("l", "circle-radius", "big", "Why."),
        )
    }

    @Test
    fun theReasonDropsTheNameTheEngineLogsFirst() {
        assertEquals(
            "value must be a number",
            StyleChecks.propertyReason("circle-radius value must be a number", "circle-radius"),
        )
        assertEquals("why", StyleChecks.propertyReason(" why ", "circle-radius"))
        assertEquals(
            "MapLibre rejected the value.",
            StyleChecks.propertyReason("circle-radius", "circle-radius"),
        )
    }

    @Test
    fun anImageSourceNeedsAUrlAndFourCornersOnTheMap() {
        val corners = listOf(listOf(-2, 2), listOf(2, 2), listOf(2, -2), listOf(-2.5, -2.5))
        assertTrue(StyleChecks.isImageSource(mapOf("url" to "u", "coordinates" to corners)))
        assertFalse(StyleChecks.isImageSource(mapOf("coordinates" to corners)))
        assertFalse(StyleChecks.isImageSource(mapOf("url" to "", "coordinates" to corners)))
        assertFalse(StyleChecks.isImageSource(mapOf<String, Any>("url" to "u")))
        for (wrong in listOf(
            corners.take(3),
            corners.take(3) + listOf(listOf(1)),
            corners.take(3) + listOf(listOf(1, 95)),
            corners.take(3) + listOf(listOf("1", "2")),
            corners.take(3) + listOf(listOf(Double.NaN, 2)),
            corners + listOf(listOf(1, 2)),
        )) {
            assertFalse(
                "$wrong",
                StyleChecks.isImageSource(mapOf("url" to "u", "coordinates" to wrong)),
            )
        }
    }
}
