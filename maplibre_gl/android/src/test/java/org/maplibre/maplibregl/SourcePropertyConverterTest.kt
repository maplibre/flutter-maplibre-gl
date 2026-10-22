package org.maplibre.maplibregl

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The tile set values the engine would reject with an Error the call cannot catch. */
class SourcePropertyConverterTest {
    @Test
    fun boundsAreFourFiniteNumbersWithTheLatitudesClampedToThePoles() {
        assertArrayEquals(
            arrayOf(-180f, -85f, 180f, 85f),
            SourcePropertyConverter.tileBounds(listOf(-180.0, -85.0, 180.0, 85.0)),
        )
        assertArrayEquals(
            arrayOf(-10f, -90f, 10f, 90f),
            SourcePropertyConverter.tileBounds(listOf(-10, -95.0, 10, 95.0)),
        )
    }

    @Test
    fun otherBoundsAreRejected() {
        for (bounds in listOf(
            "bounds",
            listOf(1.0, 2.0, 3.0),
            listOf(1.0, 2.0, 3.0, 4.0, 5.0),
            listOf(1.0, Double.NaN, 3.0, 4.0),
            listOf(1.0, 2.0, Double.POSITIVE_INFINITY, 4.0),
            listOf(1.0, "2", 3.0, 4.0),
            listOf(1.0, 10.0, 3.0, 5.0),
            listOf(10.0, 2.0, 3.0, 4.0),
        )) {
            assertRejected("$bounds") { SourcePropertyConverter.tileBounds(bounds) }
        }
    }

    @Test
    fun aTileZoomIsANumberFromZeroTo255() {
        assertNull(SourcePropertyConverter.tileZoom(null))
        assertEquals(0f, SourcePropertyConverter.tileZoom(0)!!, 0f)
        assertEquals(22.5f, SourcePropertyConverter.tileZoom(22.5)!!, 0f)
        for (zoom in listOf(-1, 256, Double.NaN, "3")) {
            assertRejected("$zoom") { SourcePropertyConverter.tileZoom(zoom) }
        }
    }

    @Test
    fun aTileSetWithMinzoomAboveMaxzoomIsRejected() {
        val tiles = listOf("https://tiles.invalid/{z}/{x}/{y}.pbf")
        assertRejected("minzoom 10, maxzoom 5") {
            SourcePropertyConverter.buildTileset(mapOf("tiles" to tiles, "minzoom" to 10, "maxzoom" to 5))
        }
    }

    @Test
    fun aGeoJsonSourceWithAnEmptyUrlIsNotBuilt() {
        assertNull(SourcePropertyConverter.buildSource("s", "geojson", mapOf("data" to "")))
    }

    @Test
    fun anUnknownTypeIsNotSupported() {
        for (type in listOf("vector", "raster", "raster-dem", "image", "geojson")) {
            assertTrue(type, SourcePropertyConverter.isSupportedType(type))
        }
        assertEquals(false, SourcePropertyConverter.isSupportedType("video"))
        assertNull(SourcePropertyConverter.buildSource("s", "video", mapOf()))
    }

    private fun assertRejected(label: String, block: () -> Unit) {
        try {
            block()
        } catch (e: IllegalArgumentException) {
            return
        }
        throw AssertionError("$label was accepted")
    }
}
