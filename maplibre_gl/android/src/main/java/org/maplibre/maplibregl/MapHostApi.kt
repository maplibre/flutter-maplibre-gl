package org.maplibre.maplibregl

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The calls of one map, from Dart. Each one goes to the [MapCalls] method of
 * the same name, with the same arguments, which answers through a
 * [MethodChannel.Result]: [PigeonMethodResult] hands that answer to Pigeon.
 *
 * Every call but [mapWaitForMap], [mapPause] and [mapResume] needs the native
 * map, which is null while the MapView is being rebuilt after the activity was
 * recreated. Such a call is answered MAP_NOT_READY then, without reaching [map].
 */
internal class MapHostApi(private val map: MapCalls) : MapLibreMapHostApi {

    // Answered once the map is ready.
    override fun mapWaitForMap(callback: (Result<Unit>) -> Unit) =
        answer(PigeonMethodResult.unit(callback)) { map.mapWaitForMap(it) }

    override fun mapUpdate(options: Map<String, Any?>, callback: (Result<Any?>) -> Unit) =
        any(callback) { map.mapUpdate(options, it) }

    override fun cameraAnimate(
        cameraUpdate: List<Any?>,
        duration: Long?,
        callback: (Result<Boolean?>) -> Unit,
    ) = call(callback, { it as Boolean? }) { map.cameraAnimate(cameraUpdate, duration, it) }

    override fun cameraMove(cameraUpdate: List<Any?>, callback: (Result<Boolean?>) -> Unit) =
        call(callback, { it as Boolean? }) { map.cameraMove(cameraUpdate, it) }

    override fun mapUpdateMyLocationTrackingMode(mode: Long, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapUpdateMyLocationTrackingMode(mode, it) }

    override fun locationComponentSetTrackingCameraOptions(
        tilt: Double,
        duration: Long?,
        callback: (Result<Boolean?>) -> Unit,
    ) = call(callback, { it as Boolean? }) {
        map.locationComponentSetTrackingCameraOptions(tilt, duration, it)
    }

    override fun locationComponentSetManualLocation(
        update: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.locationComponentSetManualLocation(update, it) }

    override fun mapMatchMapLanguageWithDeviceDefault(callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapMatchMapLanguageWithDeviceDefault(it) }

    override fun mapUpdateContentInsets(
        bounds: Map<String, Double>,
        animated: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.mapUpdateContentInsets(bounds, animated, it) }

    override fun mapSetMapLanguage(language: String, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapSetMapLanguage(language, it) }

    override fun mapSetTelemetryEnabled(enabled: Boolean, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapSetTelemetryEnabled(enabled, it) }

    override fun mapGetTelemetryEnabled(callback: (Result<Boolean>) -> Unit) =
        call(callback, { it as Boolean }) { map.mapGetTelemetryEnabled(it) }

    override fun mapSetMaximumFps(fps: Long, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapSetMaximumFps(fps, it) }

    override fun mapForceOnlineMode(callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapForceOnlineMode(it) }

    override fun mapPause(callback: (Result<Unit>) -> Unit) =
        answer(PigeonMethodResult.unit(callback)) { map.mapPause(it) }

    override fun mapResume(callback: (Result<Unit>) -> Unit) =
        answer(PigeonMethodResult.unit(callback)) { map.mapResume(it) }

    override fun cameraEase(
        cameraUpdate: List<Any?>,
        duration: Long?,
        interpolation: String?,
        callback: (Result<Boolean>) -> Unit,
    ) = call(callback, { it as Boolean }) {
        map.cameraEase(cameraUpdate, duration, interpolation, it)
    }

    override fun mapQueryCameraPosition(callback: (Result<Any?>) -> Unit) =
        any(callback) { map.mapQueryCameraPosition(it) }

    override fun mapEditGeoJsonSource(id: String, data: String, callback: (Result<Any?>) -> Unit) =
        any(callback) { map.mapEditGeoJsonSource(id, data, it) }

    override fun mapEditGeoJsonUrl(id: String, url: String, callback: (Result<Any?>) -> Unit) =
        any(callback) { map.mapEditGeoJsonUrl(id, url, it) }

    override fun mapSetLayerFilter(id: String, filter: String, callback: (Result<Any?>) -> Unit) =
        any("map#setLayerFilter", hashMapOf("id" to id, "filter" to filter), callback)

    override fun mapGetStyle(callback: (Result<Any?>) -> Unit) = any("map#getStyle", null, callback)

    override fun mapSetCustomHeaders(
        headers: Map<String, String>,
        filter: List<String>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.mapSetCustomHeaders(headers, filter, it) }

    override fun mapGetCustomHeaders(callback: (Result<Any?>) -> Unit) =
        any(callback) { map.mapGetCustomHeaders(it) }

    override fun mapQueryRenderedFeaturesAtPoint(
        x: Double,
        y: Double,
        layerIds: List<String>,
        filter: List<Any?>?,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) { map.mapQueryRenderedFeaturesAtPoint(x, y, layerIds, filter, it) }

    override fun mapQueryRenderedFeaturesInRect(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        layerIds: List<String>,
        filter: String?,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) {
        map.mapQueryRenderedFeaturesInRect(left, top, right, bottom, layerIds, filter, it)
    }

    override fun mapQuerySourceFeatures(
        sourceId: String,
        sourceLayerId: String?,
        filter: List<Any?>?,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) { map.mapQuerySourceFeatures(sourceId, sourceLayerId, filter, it) }

    // The SDK answers an int.
    override fun sourceGetClusterExpansionZoom(
        sourceId: String,
        clusterId: Long,
        callback: (Result<Long>) -> Unit,
    ) = call(callback, { (it as Number).toLong() }) {
        map.sourceGetClusterExpansionZoom(sourceId, clusterId, it)
    }

    override fun sourceGetClusterChildren(
        sourceId: String,
        clusterId: Long,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) { map.sourceGetClusterChildren(sourceId, clusterId, it) }

    override fun sourceGetClusterLeaves(
        sourceId: String,
        clusterId: Long,
        limit: Long,
        offset: Long,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) { map.sourceGetClusterLeaves(sourceId, clusterId, limit, offset, it) }

    override fun mapInvalidateAmbientCache(callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapInvalidateAmbientCache(it) }

    override fun mapClearAmbientCache(callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapClearAmbientCache(it) }

    override fun locationComponentGetLastLocation(callback: (Result<Any?>) -> Unit) =
        any(callback) { map.locationComponentGetLastLocation(it) }

    override fun mapGetVisibleRegion(callback: (Result<Any?>) -> Unit) =
        any(callback) { map.mapGetVisibleRegion(it) }

    override fun styleAddImage(
        name: String,
        bytes: ByteArray,
        length: Long,
        sdf: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "style#addImage",
        hashMapOf("name" to name, "bytes" to bytes, "length" to length, "sdf" to sdf),
        callback,
    )

    override fun styleAddImageSource(
        imageSourceId: String,
        bytes: ByteArray,
        length: Long,
        coordinates: List<Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addSource(imageSourceId, callback) {
        map.styleAddImageSource(imageSourceId, bytes, length, coordinates, it)
    }

    override fun styleUpdateImageSource(
        imageSourceId: String,
        bytes: ByteArray?,
        length: Long?,
        coordinates: List<Any?>?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.styleUpdateImageSource(imageSourceId, bytes, length, coordinates, it) }

    override fun mapToScreenLocation(
        latitude: Double,
        longitude: Double,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) { map.mapToScreenLocation(latitude, longitude, it) }

    // Answered with the screen points as a double[], x and y in turn.
    override fun mapToScreenLocationBatch(
        coordinates: DoubleArray,
        callback: (Result<DoubleArray>) -> Unit,
    ) = call(callback, { it as DoubleArray }) { map.mapToScreenLocationBatch(coordinates, it) }

    override fun styleRemoveSource(sourceId: String, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.styleRemoveSource(sourceId, it) }

    override fun styleAddLayer(
        imageLayerId: String,
        imageSourceId: String,
        minzoom: Double?,
        maxzoom: Double?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "style#addLayer",
        hashMapOf(
            "imageLayerId" to imageLayerId,
            "imageSourceId" to imageSourceId,
            "minzoom" to minzoom,
            "maxzoom" to maxzoom,
        ),
        callback,
    )

    override fun styleAddLayerBelow(
        imageLayerId: String,
        imageSourceId: String,
        belowLayerId: String,
        minzoom: Double?,
        maxzoom: Double?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "style#addLayerBelow",
        hashMapOf(
            "imageLayerId" to imageLayerId,
            "imageSourceId" to imageSourceId,
            "belowLayerId" to belowLayerId,
            "minzoom" to minzoom,
            "maxzoom" to maxzoom,
        ),
        callback,
    )

    override fun styleRemoveLayer(layerId: String, callback: (Result<Unit>) -> Unit) =
        unit("style#removeLayer", hashMapOf("layerId" to layerId), callback)

    override fun styleMoveLayer(
        layerId: String,
        belowLayerId: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val arguments = hashMapOf<String, Any?>("layerId" to layerId)
        // Left out when null, as the legacy call did.
        if (belowLayerId != null) {
            arguments["belowLayerId"] = belowLayerId
        }
        unit("style#moveLayer", arguments, callback)
    }

    override fun styleSetFilter(layerId: String, filter: String, callback: (Result<Unit>) -> Unit) =
        unit("style#setFilter", hashMapOf("layerId" to layerId, "filter" to filter), callback)

    override fun styleGetFilter(layerId: String, callback: (Result<Any?>) -> Unit) =
        any("style#getFilter", hashMapOf("layerId" to layerId), callback)

    override fun mapToLatLng(x: Double, y: Double, callback: (Result<Any?>) -> Unit) =
        any(callback) { map.mapToLatLng(x, y, it) }

    override fun mapGetMetersPerPixelAtLatitude(
        latitude: Double,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) { map.mapGetMetersPerPixelAtLatitude(latitude, it) }

    override fun sourceAddGeoJson(
        sourceId: String,
        geojson: String,
        callback: (Result<Unit>) -> Unit,
    ) = addSource(sourceId, callback) { map.sourceAddGeoJson(sourceId, geojson, it) }

    override fun sourceSetGeoJson(
        sourceId: String,
        geojson: String,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.sourceSetGeoJson(sourceId, geojson, it) }

    override fun mapSetCameraBounds(
        west: Double,
        north: Double,
        south: Double,
        east: Double,
        padding: Long,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.mapSetCameraBounds(west, north, south, east, padding, it) }

    override fun symbolLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "symbolLayer#add",
        filteredLayerArguments(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter, properties,
        ).apply { put("enableInteraction", enableInteraction) },
        callback,
    )

    override fun lineLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "lineLayer#add",
        filteredLayerArguments(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter, properties,
        ).apply { put("enableInteraction", enableInteraction) },
        callback,
    )

    override fun layerSetProperties(
        layerId: String,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "layer#setProperties",
        hashMapOf("layerId" to layerId, "properties" to properties),
        callback,
    )

    override fun circleLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "circleLayer#add",
        filteredLayerArguments(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter, properties,
        ).apply { put("enableInteraction", enableInteraction) },
        callback,
    )

    override fun fillLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "fillLayer#add",
        filteredLayerArguments(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter, properties,
        ).apply { put("enableInteraction", enableInteraction) },
        callback,
    )

    override fun fillExtrusionLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "fillExtrusionLayer#add",
        filteredLayerArguments(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter, properties,
        ).apply { put("enableInteraction", enableInteraction) },
        callback,
    )

    override fun styleAddSource(
        sourceId: String,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addSource(sourceId, callback) { map.styleAddSource(sourceId, properties, it) }

    override fun rasterLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "rasterLayer#add",
        sourcedLayerArguments(sourceId, layerId, belowLayerId, minzoom, maxzoom, properties),
        callback,
    )

    override fun hillshadeLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "hillshadeLayer#add",
        sourcedLayerArguments(sourceId, layerId, belowLayerId, minzoom, maxzoom, properties),
        callback,
    )

    override fun colorReliefLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "colorReliefLayer#add",
        sourcedLayerArguments(sourceId, layerId, belowLayerId, minzoom, maxzoom, properties),
        callback,
    )

    override fun backgroundLayerAdd(
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "backgroundLayer#add",
        hashMapOf(
            "layerId" to layerId,
            "belowLayerId" to belowLayerId,
            "minzoom" to minzoom,
            "maxzoom" to maxzoom,
            "properties" to properties,
        ),
        callback,
    )

    override fun heatmapLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "heatmapLayer#add",
        filteredLayerArguments(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter, properties,
        ),
        callback,
    )

    override fun sourceSetFeature(
        sourceId: String,
        geojsonFeature: String,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.sourceSetFeature(sourceId, geojsonFeature, it) }

    override fun sourceSetFeatureState(
        sourceId: String,
        featureId: String,
        state: Map<String, Any?>,
        sourceLayer: String?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.sourceSetFeatureState(sourceId, featureId, state, sourceLayer, it) }

    override fun sourceRemoveFeatureState(
        sourceId: String,
        featureId: String?,
        stateKey: String?,
        sourceLayer: String?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) {
        map.sourceRemoveFeatureState(sourceId, featureId, stateKey, sourceLayer, it)
    }

    override fun sourceGetFeatureState(
        sourceId: String,
        featureId: String,
        sourceLayer: String?,
        callback: (Result<Any?>) -> Unit,
    ) = any(callback) { map.sourceGetFeatureState(sourceId, featureId, sourceLayer, it) }

    override fun styleSetLight(light: Map<String, Any?>, callback: (Result<Unit>) -> Unit) =
        unit("style#setLight", hashMapOf("light" to light), callback)

    override fun layerSetVisibility(
        layerId: String,
        visible: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "layer#setVisibility",
        hashMapOf("layerId" to layerId, "visible" to visible),
        callback,
    )

    // The handler answers an ArrayList of the ids that matched no layer.
    override fun layerSetVisibilityBatch(
        layerIds: List<String>,
        visible: Boolean,
        callback: (Result<List<String>?>) -> Unit,
    ) = call(
        "layer#setVisibilityBatch",
        hashMapOf("layerIds" to layerIds, "visible" to visible),
        callback,
    ) { reply -> (reply as List<*>?)?.map { it as String } }

    override fun layerSetZoomRange(
        layerId: String,
        minzoom: Double,
        maxzoom: Double,
        callback: (Result<Unit>) -> Unit,
    ) = unit(
        "layer#setZoomRange",
        hashMapOf("layerId" to layerId, "minzoom" to minzoom, "maxzoom" to maxzoom),
        callback,
    )

    override fun layerGetVisibility(layerId: String, callback: (Result<Boolean?>) -> Unit) =
        call("layer#getVisibility", hashMapOf("layerId" to layerId), callback) { it as Boolean? }

    // Answered with the PNG bytes.
    override fun mapTakeSnapshot(
        width: Long?,
        height: Long?,
        callback: (Result<ByteArray?>) -> Unit,
    ) = call(callback, { it as ByteArray? }) { map.mapTakeSnapshot(width, height, it) }

    override fun styleGetLayerIds(callback: (Result<Any?>) -> Unit) =
        any("style#getLayerIds", null, callback)

    override fun styleGetSourceIds(callback: (Result<Any?>) -> Unit) =
        any(callback) { map.styleGetSourceIds(it) }

    override fun styleGetLayerProperties(layerId: String, callback: (Result<Any?>) -> Unit) =
        any("style#getLayerProperties", hashMapOf("layerId" to layerId), callback)

    override fun styleGetSourceProperties(sourceId: String, callback: (Result<Any?>) -> Unit) =
        any(callback) { map.styleGetSourceProperties(sourceId, it) }

    override fun styleSetStyle(style: String, callback: (Result<Unit>) -> Unit) =
        unit("style#setStyle", hashMapOf("style" to style), callback)

    /** The keys shared by the `*Layer#add` calls that take a source layer and a filter. */
    private fun filteredLayerArguments(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String,
        properties: Map<String, Any?>,
    ) = hashMapOf<String, Any?>(
        "sourceId" to sourceId,
        "layerId" to layerId,
        "belowLayerId" to belowLayerId,
        "sourceLayer" to sourceLayer,
        "minzoom" to minzoom,
        "maxzoom" to maxzoom,
        "filter" to filter,
        "properties" to properties,
    )

    /** The keys of the `*Layer#add` calls that take a source but no filter. */
    private fun sourcedLayerArguments(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
    ) = hashMapOf<String, Any?>(
        "sourceId" to sourceId,
        "layerId" to layerId,
        "belowLayerId" to belowLayerId,
        "minzoom" to minzoom,
        "maxzoom" to maxzoom,
        "properties" to properties,
    )

    /** Runs [body], which needs the map, for a call whose answer Dart does not read. */
    private fun unit(callback: (Result<Unit>) -> Unit, body: (MethodChannel.Result) -> Unit) =
        withMap(PigeonMethodResult.unit(callback), body)

    /** Runs [body], which needs the map, for a call whose answer goes to Dart as it is. */
    private fun any(callback: (Result<Any?>) -> Unit, body: (MethodChannel.Result) -> Unit) =
        withMap(PigeonMethodResult(callback) { it }, body)

    /**
     * Runs [body], which needs the map, for a call whose answer [convert] turns
     * into the type the Pigeon method returns.
     */
    private fun <T> call(
        callback: (Result<T>) -> Unit,
        convert: (Any?) -> T,
        body: (MethodChannel.Result) -> Unit,
    ) = withMap(PigeonMethodResult(callback, convert), body)

    /**
     * Runs [body], which adds a source, unless the style already holds one
     * with [sourceId]: the map answers that call SOURCE_ALREADY_EXISTS.
     */
    private fun addSource(
        sourceId: String,
        callback: (Result<Unit>) -> Unit,
        body: (MethodChannel.Result) -> Unit,
    ) = unit(callback) {
        if (!map.rejectDuplicateSourceId(sourceId, it)) {
            body(it)
        }
    }

    /** Runs [body] if the map is ready, and answers MAP_NOT_READY otherwise. */
    private fun withMap(result: MethodChannel.Result, body: (MethodChannel.Result) -> Unit) =
        answer(result) {
            if (map.isMapReady) {
                body(it)
            } else {
                it.error(MAP_NOT_READY, MAP_NOT_READY_MESSAGE, null)
            }
        }

    /**
     * Runs [body] with [result]. What it throws is answered with code "error":
     * Pigeon does not catch what an asynchronous handler throws, which would
     * reach Dart as a channel-error.
     */
    private fun answer(result: MethodChannel.Result, body: (MethodChannel.Result) -> Unit) {
        try {
            body(result)
        } catch (e: RuntimeException) {
            Log.e(TAG, "A map call failed", e)
            result.error("error", e.message, Log.getStackTraceString(e))
        }
    }

    /** Runs a call not yet typed, whose answer Dart does not read. */
    private fun unit(method: String, arguments: Any?, callback: (Result<Unit>) -> Unit) =
        call(method, arguments, callback) { }

    /** Runs a call not yet typed, whose answer goes to Dart as the handler gave it. */
    private fun any(method: String, arguments: Any?, callback: (Result<Any?>) -> Unit) =
        call(method, arguments, callback) { it }

    /**
     * Hands [method] with [arguments] to the handler, and its answer, turned
     * by [convert] into the type the Pigeon method returns, to [callback].
     */
    private fun <T> call(
        method: String,
        arguments: Any?,
        callback: (Result<T>) -> Unit,
        convert: (Any?) -> T,
    ) = answer(PigeonMethodResult(callback, convert)) {
        map.onMethodCall(MethodCall(method, legacyInts(arguments)), it)
    }

    companion object {
        private const val TAG = "MapHostApi"
        private const val MAP_NOT_READY = "MAP_NOT_READY"
        private const val MAP_NOT_READY_MESSAGE =
            "Map is not ready (activity may have been recreated)"

        /**
         * [value] with every Long that fits in 32 bits turned into an Int, in
         * nested maps and lists too. Pigeon delivers every Dart int as a Long,
         * while the method channel delivered an Integer when the value fit, and
         * the handler casts to Integer. Maps and lists are copied into a
         * HashMap and an ArrayList, the types the method channel delivered;
         * everything else is left as it is.
         */
        private fun legacyInts(value: Any?): Any? = when (value) {
            is Long -> if (value.toInt().toLong() == value) value.toInt() else value
            is Map<*, *> -> HashMap<Any?, Any?>(value.size).also { copy ->
                for ((key, item) in value) {
                    copy[key] = legacyInts(item)
                }
            }
            is List<*> -> ArrayList<Any?>(value.size).also { copy ->
                for (item in value) {
                    copy.add(legacyInts(item))
                }
            }
            else -> value
        }
    }
}
