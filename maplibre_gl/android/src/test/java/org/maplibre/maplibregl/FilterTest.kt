package org.maplibre.maplibregl

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Filters travel as the JSON text of an expression. Null is no filter, and so is the text `null`.
 */
class FilterTest {
    @Test
    fun aQueryHasNoFilterForNullOrTheTextNull() {
        assertNull(PigeonConvert.toQueryFilter(null))
        assertNull(PigeonConvert.toQueryFilter("null"))
    }

    @Test
    fun aQueryFiltersOnlyWithAnExpressionArray() {
        assertNull(PigeonConvert.toQueryFilter("true"))
        assertNull(PigeonConvert.toQueryFilter("{\"kind\":\"park\"}"))

        val filter = PigeonConvert.toQueryFilter("[\"==\",[\"get\",\"kind\"],\"park\"]")

        assertNotNull(filter)
        assertEquals("==", filter!!.toArray()[0])
    }

    @Test
    fun aLayerHasNoFilterForNullOrTheTextNull() {
        assertNull(MapLibreMapController.parseFilter(null))
        assertNull(MapLibreMapController.parseFilter("null"))
    }

    @Test
    fun aLayerFilterKeepsItsNumbersExact() {
        val filter = MapLibreMapController.parseFilter("[\"==\",[\"get\",\"id\"],123456789]")

        assertArrayEquals(arrayOf("==", arrayOf<Any?>("get", "id"), 123456789.0), filter!!.toArray())
    }

    @Test
    fun aBooleanLayerFilterIsALiteral() {
        assertArrayEquals(arrayOf<Any?>("literal", false), MapLibreMapController.parseFilter("false")!!.toArray())
    }

    @Test
    fun aLayerFilterIsAnExpressionArrayOrABoolean() {
        assertThrows(IllegalArgumentException::class.java) { MapLibreMapController.parseFilter("5") }
        assertThrows(IllegalArgumentException::class.java) { MapLibreMapController.parseFilter("[1, 2]") }
    }
}
