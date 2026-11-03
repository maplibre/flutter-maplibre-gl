package org.maplibre.maplibregl

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.maplibre.android.geometry.LatLng

/**
 * Pigeon delivers every Dart int as a Long, in nested maps and lists too. The ints the platform
 * API takes are narrowed by Convert.toIntExact, and the readers of nested payloads take any Number.
 */
class ConvertTest {
    @Test
    fun toIntExactKeepsEveryValueThatFitsIn32Bits() {
        for (value in listOf(0L, 1L, -1L, 30L, Int.MAX_VALUE.toLong(), Int.MIN_VALUE.toLong())) {
            assertEquals(value.toInt(), Convert.toIntExact(value))
        }
    }

    @Test
    fun toIntExactRejectsAValueThatDoesNotFitIn32Bits() {
        for (value in listOf(Int.MAX_VALUE + 1L, Int.MIN_VALUE - 1L, 3_000_000_000L, Long.MAX_VALUE)) {
            val error = assertThrows(IllegalArgumentException::class.java) { Convert.toIntExact(value) }
            assertEquals("$value does not fit in a 32-bit int.", error.message)
        }
    }

    @Test
    fun theNumberReadersTakeLongs() {
        assertEquals(12, Convert.toInt(12L))
        assertEquals(12f, Convert.toFloat(12L))
        assertEquals(12.0, Convert.toDouble(12L), 0.0)
    }

    @Test
    fun screenPixelsConvertBothWays() {
        // At density 2.625, 100 logical pixels are 262.5 physical ones.
        assertEquals(262.5f, Convert.toFractionalPixels(100.0, 2.625f))
        assertEquals(100.0, Convert.toLogicalPixels(262.5f, 2.625f), 0.0)
    }

    @Test
    fun toIntKeepsTheBitsOfAColorAbove32BitsSigned() {
        // An opaque ARGB color is above Int.MAX_VALUE as a Dart int.
        assertEquals(0xFF336699.toInt(), Convert.toInt(0xFF336699L))
    }

    @Test
    fun aLatLngListReadsLongs() {
        assertEquals(
            listOf(LatLng(45.0, 9.0), LatLng(46.5, 10.0)),
            Convert.toLatLngList(listOf(listOf(45L, 9L), listOf(46.5, 10L)), false),
        )
    }

    @Test
    fun theGeoJsonOptionsReadLongs() {
        val options = SourcePropertyConverter.buildGeojsonOptions(
            mapOf(
                "buffer" to 64L,
                "cluster" to true,
                "clusterMaxZoom" to 14L,
                "clusterRadius" to 50L,
                "clusterMinPoints" to 3L,
                "maxzoom" to 18L,
                "tolerance" to 1L,
            ),
        )

        assertEquals(64, options["buffer"])
        assertEquals(14, options["clusterMaxZoom"])
        assertEquals(50, options["clusterRadius"])
        assertEquals(3, options["clusterMinPoints"])
        assertEquals(18, options["maxzoom"])
        assertEquals(1f, options["tolerance"])
    }

    @Test
    fun aLayerPropertyReadsALongAsItReadsAnInt() {
        assertEquals(
            LayerPropertyConverter.interpretCircleLayerProperties(
                mapOf("circle-radius" to 5, "circle-blur" to listOf("get", "blur")),
            ).map { it.toString() },
            LayerPropertyConverter.interpretCircleLayerProperties(
                mapOf("circle-radius" to 5L, "circle-blur" to listOf("get", "blur")),
            ).map { it.toString() },
        )
    }
}
