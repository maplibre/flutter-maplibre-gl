package org.maplibre.maplibregl

import org.junit.Assert.assertArrayEquals
import org.junit.Test
import org.maplibre.android.style.expressions.Expression

/**
 * Layer properties and cluster properties reach the engine with exact numbers, as filters do, so a
 * large id still matches. Expression.Converter turned 123456789 into the float 123456792.
 */
class ExactExpressionTest {
    private fun circleProperty(name: String, value: Any): Array<Any?> {
        val values = LayerPropertyConverter.interpretCircleLayerProperties(mapOf(name to value))
        return (values.single().value as Expression).toArray()
    }

    @Test
    fun aLayerPropertyKeepsItsNumbersExact() {
        val match = listOf("match", listOf("get", "osm_id"), 123456789, "#f00", "#00f")

        assertArrayEquals(
            arrayOf("match", arrayOf<Any?>("get", "osm_id"), 123456789.0, "#f00", "#00f"),
            circleProperty("circle-color", match),
        )
    }

    @Test
    fun aConstantLayerPropertyIsALiteral() {
        assertArrayEquals(arrayOf<Any?>("literal", 123456789.0), circleProperty("circle-sort-key", 123456789))
        assertArrayEquals(arrayOf<Any?>("literal", "#f00"), circleProperty("circle-color", "#f00"))
    }

    @Test
    fun withinAndDistanceGetTheirGeoJsonAsText() {
        val ring = listOf(listOf(0, 0), listOf(1, 0), listOf(0, 1), listOf(0, 0))
        val polygon = mapOf("type" to "Polygon", "coordinates" to listOf(ring))
        val geoJson = """{"type":"Polygon","coordinates":[[[0,0],[1,0],[0,1],[0,0]]]}"""

        val within = circleProperty("circle-opacity", listOf("case", listOf("within", polygon), 1, 0))
        assertArrayEquals(arrayOf<Any?>("within", mapOf("type" to "Polygon", "json" to geoJson)), within[1] as Array<*>)

        val distance = circleProperty("circle-radius", listOf("distance", polygon))
        assertArrayEquals(arrayOf<Any?>("distance", mapOf("json" to geoJson)), distance)
    }

    @Test
    fun aClusterPropertyKeepsItsNumbersExact() {
        val options = SourcePropertyConverter.buildGeojsonOptions(
            mapOf(
                "clusterProperties" to mapOf(
                    "big" to listOf("max", listOf("==", listOf("get", "id"), 123456789)),
                    "sum" to listOf(listOf("+", listOf("accumulated"), listOf("get", "sum")), listOf("get", "n")),
                ),
            ),
        )

        val properties = options["clusterProperties"] as Map<*, *>
        val big = properties["big"] as Array<*>
        assertArrayEquals(arrayOf<Any?>("max", arrayOf<Any?>("accumulated"), arrayOf<Any?>("get", "big")), big[0] as Array<*>)
        assertArrayEquals(arrayOf<Any?>("==", arrayOf<Any?>("get", "id"), 123456789.0), big[1] as Array<*>)
        val sum = properties["sum"] as Array<*>
        assertArrayEquals(arrayOf<Any?>("+", arrayOf<Any?>("accumulated"), arrayOf<Any?>("get", "sum")), sum[0] as Array<*>)
        assertArrayEquals(arrayOf<Any?>("get", "n"), sum[1] as Array<*>)
    }
}
