package org.maplibre.maplibregl

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Method
import java.lang.reflect.Proxy

/**
 * MapHostApi hands each Pigeon call to the MapCalls method of the same name, unless the map is not
 * ready, and turns the answer into the Pigeon reply. A proxy stands in for the controller: it
 * records each call and answers through the MethodChannel.Result it is given.
 */
class MapHostApiTest {
    /** A call the stand-in received: the MapCalls method and its arguments, without the result. */
    private data class Call(val method: String, val arguments: List<Any?>)

    private val calls = mutableListOf<Call>()

    /** What isMapReady answers. */
    private var mapReady = true

    /** The source and layer ids the stand-in reports as taken. */
    private var takenIds = setOf<String>()

    /** The duplicate checks the stand-in received: the check and the id. */
    private val checks = mutableListOf<Pair<String, Any?>>()

    /** How the stand-in answers: a success with null unless a test says otherwise. */
    private var answer: (Call, MethodChannel.Result) -> Unit = { _, result -> result.success(null) }

    private val map = Proxy.newProxyInstance(
        MapCalls::class.java.classLoader,
        arrayOf(MapCalls::class.java),
    ) { proxy, method, args ->
        when (method.name) {
            "isMapReady" -> mapReady
            "rejectDuplicateLayerId", "rejectDuplicateSourceId" -> {
                val id = args!![0] as String
                checks.add(method.name to id)
                val taken = id in takenIds
                if (taken) {
                    (args[1] as MethodChannel.Result).error("ALREADY_EXISTS", id, null)
                }
                taken
            }
            "equals" -> proxy === args!![0]
            "hashCode" -> System.identityHashCode(proxy)
            "toString" -> "MapCalls stand-in"
            else -> {
                val arguments = args.orEmpty().toList()
                val call = Call(method.name, arguments.dropLast(1))
                calls.add(call)
                answer(call, arguments.last() as MethodChannel.Result)
                null
            }
        }
    } as MapCalls

    private val api = MapHostApi(map)

    /** The methods of the Pigeon host API, each ending with the callback. */
    private val pigeonMethods: List<Method> =
        MapLibreMapHostApi::class.java.declaredMethods.sortedBy { it.name }

    /**
     * The Pigeon methods that add a source or a layer, with the duplicate check they make first
     * and the position of the id it checks.
     */
    private val duplicateChecks = mapOf(
        "sourceAddGeoJson" to ("rejectDuplicateSourceId" to 0),
        "styleAddSource" to ("rejectDuplicateSourceId" to 0),
        "styleAddImageSource" to ("rejectDuplicateSourceId" to 0),
        "symbolLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "lineLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "fillLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "fillExtrusionLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "circleLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "rasterLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "hillshadeLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "colorReliefLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "heatmapLayerAdd" to ("rejectDuplicateLayerId" to 1),
        "backgroundLayerAdd" to ("rejectDuplicateLayerId" to 0),
        "styleAddLayer" to ("rejectDuplicateLayerId" to 0),
        "styleAddLayerBelow" to ("rejectDuplicateLayerId" to 0),
    )

    /** An argument of [type] that tells position [index] apart from the others. */
    private fun argument(type: Class<*>, index: Int): Any = when (type) {
        String::class.java -> "argument $index"
        java.lang.Long.TYPE, java.lang.Long::class.java -> 100L + index
        java.lang.Double.TYPE, java.lang.Double::class.java -> index + 0.5
        java.lang.Boolean.TYPE, java.lang.Boolean::class.java -> index % 2 == 0
        List::class.java -> listOf("item $index")
        Map::class.java -> mapOf("key $index" to index)
        ByteArray::class.java -> byteArrayOf(index.toByte())
        DoubleArray::class.java -> doubleArrayOf(index.toDouble())
        PgMapOptions::class.java -> PgMapOptions(compassEnabled = index % 2 == 0)
        PgCameraUpdate::class.java -> PgCameraUpdateZoomTo(index.toDouble())
        PgCameraAnimationInterpolation::class.java -> PgCameraAnimationInterpolation.entries[index % 4]
        PgMyLocationTrackingMode::class.java -> PgMyLocationTrackingMode.entries[index % 4]
        PgManualLocationUpdate::class.java -> PgManualLocationUpdate(latLng(index), 1_000L + index)
        PgEdgeInsets::class.java -> PgEdgeInsets(index.toDouble(), 1.0, 2.0, 3.0)
        PgLatLngQuad::class.java ->
            PgLatLngQuad(latLng(index), latLng(index + 1), latLng(index + 2), latLng(index + 3))
        else -> throw AssertionError("No argument for $type")
    }

    private fun latLng(index: Int) = PgLatLng(index.toDouble(), index + 0.5)

    /**
     * Calls the Pigeon [method] of the api with arguments told apart by their position. Returns
     * them, and the answers the callback got.
     */
    private fun invoke(method: Method): Pair<List<Any>, List<Result<Any?>>> {
        val answers = mutableListOf<Result<Any?>>()
        val callback: (Result<Any?>) -> Unit = { answers.add(it) }
        val arguments = method.parameterTypes.dropLast(1).mapIndexed { index, type -> argument(type, index) }
        method.invoke(api, *arguments.toTypedArray(), callback)
        return arguments to answers
    }

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
    fun mapCallsHasAMethodForEveryPigeonMethodAndNoOther() {
        val notCalls = setOf("isMapReady", "rejectDuplicateLayerId", "rejectDuplicateSourceId")

        assertEquals(78, pigeonMethods.size)
        assertEquals(
            pigeonMethods.map { it.name }.toSet(),
            MapCalls::class.java.methods.map { it.name }.toSet() - notCalls,
        )
    }

    @Test
    fun everyCallReachesTheMapCallOfTheSameNameWithItsArguments() {
        for (method in pigeonMethods) {
            calls.clear()

            val (arguments, answers) = invoke(method)

            assertEquals(method.name, listOf(method.name), calls.map { it.method })
            assertArrayEquals(method.name, arguments.toTypedArray(), calls.single().arguments.toTypedArray())
            assertEquals(method.name, 1, answers.size)
        }
    }

    @Test
    fun withoutTheMapEveryCallButWaitForMapPauseAndResumeAnswersMapNotReady() {
        mapReady = false
        for (method in pigeonMethods) {
            calls.clear()

            val (_, answers) = invoke(method)

            if (method.name in setOf("mapWaitForMap", "mapPause", "mapResume")) {
                assertEquals(method.name, listOf(method.name), calls.map { it.method })
                assertTrue(method.name, answers.single().isSuccess)
            } else {
                assertEquals(method.name, emptyList<Call>(), calls)
                assertEquals(method.name, emptyList<Pair<String, Any?>>(), checks)
                val error = answers.single().exceptionOrNull() as PigeonError
                assertEquals(method.name, "MAP_NOT_READY", error.code)
                assertEquals("Map is not ready (activity may have been recreated)", error.message)
                assertNull(error.details)
            }
        }
    }

    @Test
    fun theCallsThatAddASourceOrALayerCheckTheirIdFirst() {
        for (method in pigeonMethods) {
            checks.clear()

            val (arguments, _) = invoke(method)

            val check = duplicateChecks[method.name]
            assertEquals(
                method.name,
                listOfNotNull(check?.let { (name, position) -> name to arguments[position] }),
                checks,
            )
        }
    }

    @Test
    fun aCallThatAddsATakenIdIsAnsweredByTheCheckAlone() {
        takenIds = setOf("argument 0", "argument 1")
        val adding = pigeonMethods.filter { it.name in duplicateChecks }
        assertEquals(duplicateChecks.keys, adding.map { it.name }.toSet())
        for (method in adding) {
            calls.clear()

            val (_, answers) = invoke(method)

            assertEquals(method.name, emptyList<Call>(), calls)
            assertEquals(method.name, "ALREADY_EXISTS", (answers.single().exceptionOrNull() as PigeonError).code)
        }
    }

    @Test
    fun whatACallThrowsIsAnsweredWithCodeError() {
        answer = { _, _ -> throw IllegalStateException("boom") }
        for (method in pigeonMethods) {
            val (_, answers) = invoke(method)

            val error = answers.single().exceptionOrNull() as PigeonError
            assertEquals(method.name, "error", error.code)
            assertEquals(method.name, "boom", error.message)
            assertTrue(method.name, (error.details as String).contains("IllegalStateException"))
        }
    }

    @Test
    fun aCallThatThrowsIsNamedAfterItsPigeonMethod() {
        val names = mutableListOf<String>()
        answer = { _, _ ->
            names.add(MapHostApi.callName(IllegalStateException("boom")))
            throw IllegalStateException("boom")
        }
        for (method in pigeonMethods) {
            names.clear()

            invoke(method)

            assertEquals(method.name, listOf(method.name), names)
        }
    }

    @Test
    fun anErrorOfTheCallArrivesAsAPigeonErrorWithTheSameCode() {
        val details = hashMapOf("reason" to "disk")
        answer = { _, result -> result.error("AMBIENT_CACHE_ERROR", "No space left", details) }

        val error = failure<Unit> { api.mapClearAmbientCache(it) }

        assertEquals("AMBIENT_CACHE_ERROR", error.code)
        assertEquals("No space left", error.message)
        assertSame(details, error.details)
    }

    @Test
    fun anExceptionAfterTheAnswerDoesNotAnswerAgain() {
        answer = { _, result ->
            result.success(null)
            throw IllegalStateException("late")
        }

        val answers = answers<Unit> { api.mapPause(it) }

        assertEquals(1, answers.size)
        assertTrue(answers.single().isSuccess)
    }

    @Test
    fun deliversOnlyTheFirstAnswer() {
        answer = { _, result ->
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
        answer = { _, result ->
            result.error("first", null, null)
            result.success(null)
            result.error("second", null, null)
        }

        assertEquals("first", failure<Unit> { api.mapResume(it) }.code)
    }

    @Test
    fun aWaitForMapAnsweredLaterStillArrives() {
        var pending: MethodChannel.Result? = null
        mapReady = false
        answer = { _, result -> pending = result }
        val answers = mutableListOf<Result<Unit>>()

        api.mapWaitForMap { answers.add(it) }
        assertTrue(answers.isEmpty())
        pending!!.error("MAP_DISPOSED", "The map was disposed before it finished being created", null)

        assertEquals("MAP_DISPOSED", (answers.single().exceptionOrNull() as PigeonError).code)
    }

    @Test
    fun answersTheBooleanOfGetTelemetryEnabled() {
        answer = { _, result -> result.success(false) }

        assertEquals(false, value<Boolean> { api.mapGetTelemetryEnabled(it) })
    }

    @Test
    fun anAnswerOfTheWrongTypeArrivesAsAnError() {
        answer = { _, result -> result.success("not a boolean") }

        assertEquals("error", failure<Boolean> { api.mapGetTelemetryEnabled(it) }.code)
    }

    @Test
    fun answersTheBytesOfASnapshotAsTheyAre() {
        val png = byteArrayOf(1, 2, 3)
        answer = { _, result -> result.success(png) }

        assertSame(png, value<ByteArray?> { api.mapTakeSnapshot(100L, null, it) })
        assertEquals(listOf<Any?>(100L, null), calls.single().arguments)
    }

    @Test
    fun answersTheIntOfGetClusterExpansionZoomAsALong() {
        answer = { _, result -> result.success(9) }

        assertEquals(9L, value<Long> { api.sourceGetClusterExpansionZoom("points", 3_000_000_000L, it) })
        assertEquals(listOf<Any?>("points", 3_000_000_000L), calls.single().arguments)
    }

    @Test
    fun answersTheScreenPointsOfABatchAsTheyAre() {
        val points = doubleArrayOf(10.0, 20.0)
        answer = { _, result -> result.success(points) }

        assertSame(points, value<DoubleArray> { api.mapToScreenLocationBatch(doubleArrayOf(45.0, 9.0), it) })
    }

    @Test
    fun answersTheListOfMissingLayerIds() {
        answer = { _, result -> result.success(arrayListOf("gone")) }
        assertEquals(
            listOf("gone"),
            value<List<String>?> { api.layerSetVisibilityBatch(listOf("a", "gone"), false, it) },
        )

        answer = { _, result -> result.success(null) }
        assertNull(value<List<String>?> { api.layerSetVisibilityBatch(listOf("a"), true, it) })
    }

    @Test
    fun answersTheVisibilityOfALayerOrNull() {
        answer = { _, result -> result.success(true) }
        assertEquals(true, value<Boolean?> { api.layerGetVisibility("a", it) })

        answer = { _, result -> result.success(null) }
        assertNull(value<Boolean?> { api.layerGetVisibility("missing", it) })
    }

    @Test
    fun answersWhetherACameraMoveFinished() {
        answer = { _, result -> result.success(false) }
        val zoomIn = PgCameraUpdateZoomIn()
        val linear = PgCameraAnimationInterpolation.LINEAR

        assertEquals(false, value<Boolean?> { api.cameraMove(zoomIn, it) })
        assertEquals(false, value<Boolean?> { api.cameraAnimate(zoomIn, 300L, it) })
        assertEquals(false, value<Boolean> { api.cameraEase(zoomIn, null, linear, it) })
        assertEquals(listOf<Any?>(zoomIn, null, linear), calls.last().arguments)
    }

    @Test
    fun answersACopyOfTheCustomHeaders() {
        val headers = hashMapOf("Authorization" to "Bearer token")
        answer = { _, result -> result.success(headers) }

        val answered = value<Map<String, String>> { api.mapGetCustomHeaders(it) }

        assertEquals(headers, answered)
        assertNotSame(headers, answered)
    }

    @Test
    fun answersTheCameraPositionOfAnUpdateOrNull() {
        val position = PgCameraPosition(90.0, PgLatLng(45.0, 9.0), 30.0, 12.0)
        val options = PgMapOptions(trackCameraPosition = true)
        answer = { _, result -> result.success(position) }
        assertSame(position, value<PgCameraPosition?> { api.mapUpdate(options, it) })
        assertEquals(listOf<Any?>(options), calls.single().arguments)

        answer = { _, result -> result.success(null) }
        assertNull(value<PgCameraPosition?> { api.mapUpdate(PgMapOptions(), it) })
    }

    @Test
    fun answersTheTypedValuesOfTheQueries() {
        val point = PgScreenPoint(10.0, 20.0)
        answer = { _, result -> result.success(point) }
        assertSame(point, value<PgScreenPoint> { api.mapToScreenLocation(45.0, 9.0, it) })

        val latLng = PgLatLng(45.0, 9.0)
        answer = { _, result -> result.success(latLng) }
        assertSame(latLng, value<PgLatLng> { api.mapToLatLng(10.0, 20.0, it) })
        assertSame(latLng, value<PgLatLng> { api.locationComponentGetLastLocation(it) })

        val region = PgLatLngBounds(PgLatLng(44.0, 8.0), PgLatLng(46.0, 10.0))
        answer = { _, result -> result.success(region) }
        assertSame(region, value<PgLatLngBounds> { api.mapGetVisibleRegion(it) })

        answer = { _, result -> result.success(2.5) }
        assertEquals(2.5, value<Double> { api.mapGetMetersPerPixelAtLatitude(45.0, it) }, 0.0)
    }

    @Test
    fun answersTheFeaturesAndIdsAsListsOfStrings() {
        val features = arrayListOf("{\"type\":\"Feature\"}")
        answer = { _, result -> result.success(features) }

        assertEquals(features, value<List<String>> { api.mapQueryRenderedFeaturesAtPoint(1.0, 2.0, emptyList(), null, it) })
        assertEquals(features, value<List<String>> { api.mapQuerySourceFeatures("source", null, "null", it) })
        assertEquals(features, value<List<String>> { api.sourceGetClusterLeaves("source", 1L, 10L, 0L, it) })
        assertEquals(features, value<List<String>> { api.styleGetLayerIds(it) })
    }

    @Test
    fun answersTheJsonOfTheStyleObjectsOrNull() {
        answer = { _, result -> result.success("[\"==\",\"a\",1]") }
        assertEquals("[\"==\",\"a\",1]", value<String?> { api.styleGetFilter("layer", it) })

        answer = { _, result -> result.success(null) }
        assertNull(value<String?> { api.styleGetFilter("layer", it) })
        assertNull(value<String?> { api.styleGetLayerProperties("missing", it) })
        assertNull(value<String?> { api.styleGetSourceProperties("missing", it) })
        assertNull(value<String?> { api.sourceGetFeatureState("source", "1", null, it) })
        assertNull(value<String?> { api.mapGetStyle(it) })
    }

    @Test
    fun aReplyInTheShapeOfTheMethodChannelArrivesAsAnError() {
        answer = { _, result -> result.success(mapOf("result" to true)) }

        assertEquals("error", failure<Boolean> { api.mapEditGeoJsonSource("source", "{}", it) }.code)
    }
}
