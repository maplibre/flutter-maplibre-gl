package org.maplibre.maplibregl

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.maplibre.android.camera.CameraUpdateFactory
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
        assertEquals(12L, Convert.toLong(12L))
        assertEquals(12f, Convert.toFloatWrapper(12L))
    }

    @Test
    fun toIntKeepsTheBitsOfAColorAbove32BitsSigned() {
        // An opaque ARGB color is above Int.MAX_VALUE as a Dart int.
        assertEquals(0xFF336699.toInt(), Convert.toInt(0xFF336699L))
    }

    @Test
    fun aCameraPositionReadsLongs() {
        val position = Convert.toCameraPosition(
            mapOf("bearing" to 90L, "target" to listOf(45L, 9L), "tilt" to 30L, "zoom" to 12L),
        )

        assertEquals(90.0, position.bearing, 0.0)
        assertEquals(LatLng(45.0, 9.0), position.target)
        assertEquals(30.0, position.tilt, 0.0)
        assertEquals(12.0, position.zoom, 0.0)
    }

    @Test
    fun aCameraUpdateReadsLongs() {
        val zoom = Convert.toCameraUpdate(listOf("zoomTo", 12L), null, 2f)
            as CameraUpdateFactory.ZoomUpdate
        assertEquals(12.0, zoom.zoom, 0.0)

        val zoomBy = Convert.toCameraUpdate(listOf("zoomBy", -2L), null, 2f)
            as CameraUpdateFactory.ZoomUpdate
        assertEquals(-2.0, zoomBy.zoom, 0.0)

        val position = Convert.toCameraUpdate(
            listOf("newLatLngZoom", listOf(45L, 9L), 10L), null, 2f,
        ) as CameraUpdateFactory.CameraPositionUpdate
        assertEquals(LatLng(45.0, 9.0), position.target)
        assertEquals(10.0, position.zoom, 0.0)
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
