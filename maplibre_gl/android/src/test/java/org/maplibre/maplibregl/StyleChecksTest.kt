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

    @Test
    fun theNewMessagesAreTheOnesIosGives() {
        assertEquals(
            "Source 's' is not a GeoJSON source. setGeoJsonSource only applies to GeoJSON sources.",
            StyleChecks.notGeoJsonSource("s", "setGeoJsonSource", false),
        )
        assertEquals(
            "Source 's' is not a GeoJSON source. getClusterLeaves only applies to clustered " +
                "GeoJSON sources.",
            StyleChecks.notGeoJsonSource("s", "getClusterLeaves", true),
        )
        assertEquals(
            "Source 'v' is a vector source, so layer 'l' requires a 'sourceLayer'.",
            StyleChecks.sourceLayerRequired("l", "v"),
        )
        assertEquals(
            "The minzoom and maxzoom of layer 'l' must be within 0 and 24.",
            StyleChecks.zoomOutOfRange("l"),
        )
        assertEquals(
            "Source 's' cannot be built from its properties as a 'vector' source.",
            StyleChecks.unbuildableSource("s", "vector"),
        )
        assertEquals("Padding 4294967296 does not fit in 32 bits.", StyleChecks.paddingOutOfRange(1L shl 32))
    }

    @Test
    fun aLayerZoomIsWithinZeroAndTwentyFour() {
        assertTrue(StyleChecks.isZoomInRange(null, null))
        assertTrue(StyleChecks.isZoomInRange(0.0, 24.0))
        assertTrue(StyleChecks.isZoomInRange(null, 12.5))
        for ((min, max) in listOf(-0.1 to null, null to 24.1, Double.NaN to 5.0, 1.0 to Double.NaN)) {
            assertFalse("$min $max", StyleChecks.isZoomInRange(min, max))
        }
    }

    @Test
    fun aCoordinateIsFiniteOnBothAxes() {
        assertTrue(StyleChecks.isFinite(45.0, 9.0))
        for ((lat, lng) in listOf(
            Double.NaN to 0.0,
            0.0 to Double.NaN,
            Double.POSITIVE_INFINITY to 0.0,
            0.0 to Double.NEGATIVE_INFINITY,
        )) {
            assertFalse("$lat $lng", StyleChecks.isFinite(lat, lng))
        }
    }
}
