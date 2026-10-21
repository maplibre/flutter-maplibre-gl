package org.maplibre.maplibregl

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * MapHostApi rebuilds each Pigeon call as the method call the per-map method channel delivered
 * and hands it to the controller, then turns the controller's answer into the Pigeon reply. A
 * fake handler stands in for the controller: it records each call and answers through the
 * MethodChannel.Result it is given.
 */
class MapHostApiTest {
    private class FakeHandler : MethodChannel.MethodCallHandler {
        val calls = mutableListOf<MethodCall>()

        /** How the handler answers: a success with null unless a test says otherwise. */
        var answer: (MethodCall, MethodChannel.Result) -> Unit = { _, result -> result.success(null) }

        override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
            calls.add(call)
            answer(call, result)
        }
    }

    private val handler = FakeHandler()
    private val api = MapHostApi(handler)

    /** The only call the handler received. */
    private val call: MethodCall
        get() = handler.calls.single()

    /** The arguments of each call the handler received. */
    private val arguments: List<Any?>
        get() = handler.calls.map { it.arguments }

    /** Runs [block] with a callback that collects every answer it gets. */
    private fun <T> answers(block: ((Result<T>) -> Unit) -> Unit): List<Result<T>> {
        val results = mutableListOf<Result<T>>()
        block { results.add(it) }
        return results
    }

    /** The value of the single answer [block] gets, which must be a success. */
    private fun <T> value(block: ((Result<T>) -> Unit) -> Unit): T =
        answers(block).single().getOrThrow()

    /** The error of the single answer [block] gets, which must be a failure. */
    private fun <T> failure(block: ((Result<T>) -> Unit) -> Unit): PigeonError =
        answers(block).single().exceptionOrNull() as PigeonError

    @Test
    fun keepsTheLegacyMethodNames() {
        val properties = mapOf<String, Any?>()
        api.mapWaitForMap {}
        api.mapUpdate(mapOf("compassEnabled" to true)) {}
        api.cameraMove(listOf("zoomIn")) {}
        api.cameraEase(listOf("zoomIn"), null, null) {}
        api.locationComponentGetLastLocation {}
        api.locationComponentSetTrackingCameraOptions(0.0, null) {}
        api.mapGetStyle {}
        api.mapQueryRenderedFeaturesAtPoint(1.0, 2.0, listOf(), null) {}
        api.mapQueryRenderedFeaturesInRect(1.0, 2.0, 3.0, 4.0, listOf(), null) {}
        api.mapTakeSnapshot(null, null) {}
        api.styleAddImage("pin", byteArrayOf(1), 1L, false) {}
        api.styleMoveLayer("a", null) {}
        api.styleSetStyle("{}") {}
        api.sourceGetClusterLeaves("points", 1L, 10L, 0L) {}
        api.sourceSetFeatureState("source", "1", mapOf("hover" to true), null) {}
        api.layerSetVisibility("a", true) {}
        api.layerSetVisibilityBatch(listOf("a"), true) {}
        api.symbolLayerAdd("source", "symbols", null, null, null, null, "null", true, properties) {}
        api.fillExtrusionLayerAdd("source", "3d", null, null, null, null, "null", false, properties) {}
        api.heatmapLayerAdd("source", "heat", null, null, null, null, "null", properties) {}
        api.colorReliefLayerAdd("dem", "relief", null, null, null, properties) {}
        api.backgroundLayerAdd("background", null, null, null, properties) {}

        assertEquals(
            listOf(
                "map#waitForMap",
                "map#update",
                "camera#move",
                "camera#ease",
                "locationComponent#getLastLocation",
                "locationComponent#setTrackingCameraOptions",
                "map#getStyle",
                // Both variants were one legacy call, told apart by their keys.
                "map#queryRenderedFeatures",
                "map#queryRenderedFeatures",
                "map#takeSnapshot",
                "style#addImage",
                "style#moveLayer",
                "style#setStyle",
                "source#getClusterLeaves",
                "source#setFeatureState",
                "layer#setVisibility",
                "layer#setVisibilityBatch",
                "symbolLayer#add",
                "fillExtrusionLayer#add",
                "heatmapLayer#add",
                "colorReliefLayer#add",
                "backgroundLayer#add",
            ),
            handler.calls.map { it.method },
        )
    }

    @Test
    fun sendsTheLegacyArgumentKeys() {
        val properties = mapOf<String, Any?>()
        api.sourceGetClusterLeaves("points", 3L, 10L, 0L) {}
        api.symbolLayerAdd("source", "symbols", "labels", "poi", 1.0, 2.0, "null", true, properties) {}
        api.rasterLayerAdd("raster", "layer", null, null, null, properties) {}
        api.backgroundLayerAdd("background", null, null, null, properties) {}
        api.heatmapLayerAdd("source", "heat", null, null, null, null, "null", properties) {}
        api.mapQueryRenderedFeaturesAtPoint(1.0, 2.0, listOf("a"), null) {}
        api.mapQueryRenderedFeaturesInRect(1.0, 2.0, 3.0, 4.0, listOf("a"), null) {}
        api.styleAddImage("pin", byteArrayOf(1, 2), 2L, true) {}
        api.sourceRemoveFeatureState("source", null, null, null) {}

        assertEquals(
            listOf(
                setOf("sourceId", "clusterId", "limit", "offset"),
                setOf(
                    "sourceId", "layerId", "belowLayerId", "sourceLayer", "minzoom", "maxzoom",
                    "filter", "properties", "enableInteraction",
                ),
                setOf("sourceId", "layerId", "belowLayerId", "minzoom", "maxzoom", "properties"),
                setOf("layerId", "belowLayerId", "minzoom", "maxzoom", "properties"),
                setOf(
                    "sourceId", "layerId", "belowLayerId", "sourceLayer", "minzoom", "maxzoom",
                    "filter", "properties",
                ),
                setOf("x", "y", "layerIds", "filter"),
                setOf("left", "top", "right", "bottom", "layerIds", "filter"),
                setOf("name", "bytes", "length", "sdf"),
                setOf("sourceId", "featureId", "stateKey", "sourceLayer"),
            ),
            arguments.map { (it as Map<*, *>).keys },
        )
        assertEquals(
            mapOf(
                "sourceId" to "source",
                "layerId" to "symbols",
                "belowLayerId" to "labels",
                "sourceLayer" to "poi",
                "minzoom" to 1.0,
                "maxzoom" to 2.0,
                "filter" to "null",
                "properties" to properties,
                "enableInteraction" to true,
            ),
            arguments[1],
        )
        // Sent as null values, as the legacy calls did.
        assertEquals(
            mapOf("sourceId" to "source", "featureId" to null, "stateKey" to null, "sourceLayer" to null),
            arguments[8],
        )
    }

    @Test
    fun leavesOutTheKeysTheLegacyCallsLeftOutWhenNull() {
        api.cameraEase(listOf("zoomIn"), null, null) {}
        api.cameraEase(listOf("zoomIn"), 300L, "fastOutLinearIn") {}
        api.styleMoveLayer("a", null) {}
        api.styleMoveLayer("a", "b") {}
        api.mapTakeSnapshot(null, null) {}
        api.mapTakeSnapshot(100L, null) {}
        api.mapTakeSnapshot(null, 50L) {}

        assertEquals(
            listOf(
                // The duration was sent as null, the interpolation left out.
                mapOf("cameraUpdate" to listOf("zoomIn"), "duration" to null),
                mapOf(
                    "cameraUpdate" to listOf("zoomIn"),
                    "duration" to 300,
                    "interpolation" to "fastOutLinearIn",
                ),
                mapOf("layerId" to "a"),
                mapOf("layerId" to "a", "belowLayerId" to "b"),
                // Always a map, never null.
                mapOf<String, Any?>(),
                mapOf("width" to 100),
                mapOf("height" to 50),
            ),
            arguments,
        )
        assertFalse((arguments[0] as Map<*, *>).containsKey("interpolation"))
    }

    @Test
    fun sendsNoArgumentsWhereTheLegacyCallsSentNone() {
        api.mapWaitForMap {}
        api.mapPause {}
        api.mapResume {}
        api.mapGetStyle {}
        api.mapQueryCameraPosition {}
        api.mapInvalidateAmbientCache {}
        api.styleGetLayerIds {}
        api.locationComponentGetLastLocation {}

        assertEquals(8, handler.calls.size)
        for (received in handler.calls) {
            assertNull(received.method, received.arguments)
        }
    }

    @Test
    fun setManualLocationSendsTheUpdateMapItself() {
        val update = mapOf<String, Any?>(
            "position" to listOf(45.0, 9.0),
            "timestamp" to 1_700_000_000_000L,
            "horizontalAccuracy" to 5.0,
        )

        api.locationComponentSetManualLocation(update) {}

        assertEquals("locationComponent#setManualLocation", call.method)
        assertEquals(update, call.arguments)
        // A timestamp of today does not fit in 32 bits, so it stays a Long.
        assertTrue(call.argument<Any>("timestamp") is Long)
    }

    @Test
    fun getCustomHeadersSendsAnEmptyMap() {
        api.mapGetCustomHeaders {}

        assertEquals("map#getCustomHeaders", call.method)
        assertEquals(mapOf<String, Any?>(), call.arguments)
    }

    @Test
    fun turnsLongsThatFitIn32BitsIntoIntegers() {
        api.mapSetMaximumFps(30L) {}
        api.layerSetProperties(
            "a",
            mapOf(
                "text-size" to 12L,
                "text-offset" to listOf(1L, 2.5),
                "nested" to mapOf(
                    "max" to Int.MAX_VALUE.toLong(),
                    "min" to Int.MIN_VALUE.toLong(),
                    "over" to Int.MAX_VALUE + 1L,
                    "under" to Int.MIN_VALUE - 1L,
                ),
            ),
        ) {}
        api.sourceGetClusterLeaves("points", 3_000_000_000L, 10L, -1L) {}

        val fps = handler.calls[0].argument<Any>("fps")
        assertTrue(fps is Int)
        assertEquals(30, fps)

        val properties = handler.calls[1].argument<Map<String, Any?>>("properties")!!
        assertTrue(properties["text-size"] is Int)
        assertEquals(12, properties["text-size"])
        val offset = properties["text-offset"] as List<*>
        assertTrue(offset[0] is Int)
        assertTrue(offset[1] is Double)
        assertEquals(listOf(1, 2.5), offset)
        val nested = properties["nested"] as Map<*, *>
        assertEquals(Int.MAX_VALUE, nested["max"])
        assertEquals(Int.MIN_VALUE, nested["min"])
        assertEquals(Int.MAX_VALUE + 1L, nested["over"])
        assertEquals(Int.MIN_VALUE - 1L, nested["under"])

        val leaves = handler.calls[2]
        assertEquals(3_000_000_000L, leaves.argument<Any>("clusterId"))
        assertEquals(10, leaves.argument<Any>("limit"))
        assertEquals(-1, leaves.argument<Any>("offset"))
    }

    @Test
    fun copiesMapsAndListsIntoTheTypesTheMethodChannelDelivered() {
        api.layerSetProperties("a", mapOf("text-offset" to listOf(1.0, 2.0))) {}

        val sent = call.arguments
        assertTrue(sent is HashMap<*, *>)
        val properties = (sent as Map<*, *>)["properties"]
        assertTrue(properties is HashMap<*, *>)
        assertTrue((properties as Map<*, *>)["text-offset"] is ArrayList<*>)
    }

    @Test
    fun answersTheIntegerOfGetClusterExpansionZoomAsALong() {
        handler.answer = { _, result -> result.success(9) }

        val zoom = value<Long> { api.sourceGetClusterExpansionZoom("points", 1L, it) }

        assertEquals(9L, zoom)
        assertEquals(
            mapOf("sourceId" to "points", "clusterId" to 1),
            call.arguments,
        )
    }

    @Test
    fun passesTheArraysOfTheHandlerThrough() {
        val points = doubleArrayOf(10.0, 20.0)
        val snapshot = byteArrayOf(1, 2, 3)
        handler.answer = { received, result ->
            result.success(if (received.method == "map#toScreenLocationBatch") points else snapshot)
        }

        assertSame(points, value<DoubleArray> { api.mapToScreenLocationBatch(doubleArrayOf(45.0, 9.0), it) })
        assertSame(snapshot, value<ByteArray?> { api.mapTakeSnapshot(100L, 50L, it) })
        assertArrayEquals(
            doubleArrayOf(45.0, 9.0),
            handler.calls[0].argument<DoubleArray>("coordinates"),
            0.0,
        )
    }

    @Test
    fun sendsTheBytesOfAnImageAsTheyAre() {
        val bytes = byteArrayOf(1, 2)

        api.styleAddImage("pin", bytes, 2L, true) {}

        assertSame(bytes, call.argument<ByteArray>("bytes"))
        assertEquals(2, call.argument<Any>("length"))
    }

    @Test
    fun answersTheListOfMissingLayerIds() {
        handler.answer = { _, result -> result.success(arrayListOf("gone")) }
        assertEquals(
            listOf("gone"),
            value<List<String>?> { api.layerSetVisibilityBatch(listOf("a", "gone"), false, it) },
        )

        handler.answer = { _, result -> result.success(null) }
        assertNull(value<List<String>?> { api.layerSetVisibilityBatch(listOf("a"), true, it) })
    }

    @Test
    fun answersTheReplyOfTheHandlerAsItIs() {
        val style = hashMapOf<String, Any?>("result" to true, "json" to "{}")
        handler.answer = { _, result -> result.success(style) }

        assertSame(style, value<Any?> { api.mapGetStyle(it) })
    }

    @Test
    fun answersTheBooleanOfTheHandler() {
        handler.answer = { _, result -> result.success(true) }

        assertEquals(true, value<Boolean> { api.mapGetTelemetryEnabled(it) })
        assertEquals(true, value<Boolean?> { api.layerGetVisibility("a", it) })
    }

    @Test
    fun anErrorOfTheHandlerArrivesAsAPigeonErrorWithTheSameCode() {
        val details = hashMapOf("layerId" to "missing")
        handler.answer = { _, result -> result.error("LAYER_NOT_FOUND", "No layer missing", details) }

        val error = failure<Unit> { api.styleRemoveLayer("missing", it) }

        assertEquals("LAYER_NOT_FOUND", error.code)
        assertEquals("No layer missing", error.message)
        assertSame(details, error.details)
    }

    @Test
    fun anExceptionOfTheHandlerIsAnsweredWithCodeError() {
        handler.answer = { _, _ -> throw IllegalStateException("boom") }

        val error = failure<Unit> { api.styleSetStyle("{}", it) }

        assertEquals("error", error.code)
        assertEquals("boom", error.message)
        assertTrue((error.details as String).contains("IllegalStateException"))
    }

    @Test
    fun anExceptionAfterTheAnswerDoesNotAnswerAgain() {
        handler.answer = { _, result ->
            result.success(null)
            throw IllegalStateException("late")
        }

        val answers = answers<Unit> { api.mapPause(it) }

        assertEquals(1, answers.size)
        assertTrue(answers.single().isSuccess)
    }

    @Test
    fun deliversOnlyTheFirstAnswer() {
        handler.answer = { _, result ->
            result.success(true)
            result.success(false)
            result.error("late", null, null)
            result.notImplemented()
        }

        val answers = answers<Boolean> { api.mapGetTelemetryEnabled(it) }

        assertEquals(listOf(true), answers.map { it.getOrThrow() })
    }

    @Test
    fun deliversOnlyTheFirstError() {
        handler.answer = { _, result ->
            result.error("first", null, null)
            result.success(null)
            result.error("second", null, null)
        }

        assertEquals("first", failure<Unit> { api.mapResume(it) }.code)
    }

    @Test
    fun anAnswerGivenLaterStillArrives() {
        var pending: MethodChannel.Result? = null
        handler.answer = { _, result -> pending = result }
        val answers = mutableListOf<Result<Any?>>()

        api.mapGetVisibleRegion { answers.add(it) }
        assertTrue(answers.isEmpty())
        pending!!.success("region")

        assertEquals(listOf<Any?>("region"), answers.map { it.getOrThrow() })
    }

    @Test
    fun notImplementedArrivesAsAPigeonError() {
        handler.answer = { _, result -> result.notImplemented() }

        assertEquals("notImplemented", failure<Unit> { api.mapForceOnlineMode(it) }.code)
    }

    @Test
    fun anAnswerOfTheWrongTypeArrivesAsAnError() {
        handler.answer = { _, result -> result.success("not a boolean") }

        assertEquals("error", failure<Boolean> { api.mapGetTelemetryEnabled(it) }.code)
    }
}
