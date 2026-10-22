package org.maplibre.maplibregl

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
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
        assertNull(PigeonConvert.toQueryFilter("false"))
        assertNull(PigeonConvert.toQueryFilter("3"))
        assertNull(PigeonConvert.toQueryFilter("\"park\""))
        assertNull(PigeonConvert.toQueryFilter("{\"kind\":\"park\"}"))

        val filter = PigeonConvert.toQueryFilter("[\"==\",[\"get\",\"kind\"],\"park\"]")

        assertNotNull(filter)
        assertEquals("==", filter!!.toArray()[0])
    }

    @Test
    fun aQueryFilterKeepsItsNumbersExact() {
        val filter = PigeonConvert.toQueryFilter("[\"==\",[\"get\",\"id\"],123456789]")

        assertArrayEquals(arrayOf("==", arrayOf<Any?>("get", "id"), 123456789.0), filter!!.toArray())
    }

    @Test
    fun aQueryArrayThatIsNotAnExpressionIsRejected() {
        for (filter in listOf("[]", "[1, 2]", "[[\"get\", \"n\"]]")) {
            assertThrows(filter, IllegalArgumentException::class.java) { PigeonConvert.toQueryFilter(filter) }
        }
    }

    @Test
    fun aFilterThatIsNotJsonIsRejected() {
        // Gson reads most of these as a string or an array of strings unless it reads strictly.
        for (filter in listOf("n == 3", "park", "[park]", "['==', 1, 1]", "[1,", "", " ", "[1] [2]")) {
            val query = assertThrows(filter, IllegalArgumentException::class.java) {
                PigeonConvert.toQueryFilter(filter)
            }
            assertEquals(filter, PigeonConvert.FILTER_NOT_JSON, query.message)
            val layer = assertThrows(filter, IllegalArgumentException::class.java) {
                MapLibreMapController.parseFilter(filter)
            }
            assertEquals(filter, PigeonConvert.FILTER_NOT_JSON, layer.message)
        }
    }

    @Test
    fun filterTextIsAnyJsonValue() {
        assertTrue(PigeonConvert.parseFilterJson("true").isJsonPrimitive)
        assertTrue(PigeonConvert.parseFilterJson("null").isJsonNull)
        assertTrue(PigeonConvert.parseFilterJson("3").isJsonPrimitive)
        assertTrue(PigeonConvert.parseFilterJson("\"park\"").isJsonPrimitive)
        assertTrue(PigeonConvert.parseFilterJson("{\"kind\": \"park\"}").isJsonObject)
        assertTrue(PigeonConvert.parseFilterJson(" [\"has\", \"kind\"] ").isJsonArray)
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
