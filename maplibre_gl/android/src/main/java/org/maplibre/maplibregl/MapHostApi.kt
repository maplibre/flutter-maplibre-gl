package org.maplibre.maplibregl

import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * The calls of one map, from Dart. Each one goes to the [MapCalls] method of
 * the same name, and [PigeonMethodResult] hands its [MethodChannel.Result]
 * answer to Pigeon.
 *
 * While the MapView is being rebuilt after an activity recreation, every call
 * but [mapWaitForMap], [mapPause] and [mapResume] is answered MAP_NOT_READY
 * without reaching [map].
 */
internal class MapHostApi(private val map: MapCalls) : MapLibreMapHostApi {

    // Answered once the map is ready.
    override fun mapWaitForMap(callback: (Result<Unit>) -> Unit) =
        answer(PigeonMethodResult.unit(callback)) { map.mapWaitForMap(it) }

    // Answered with the camera position, or null when the map does not track it.
    override fun mapUpdate(
        options: PgMapOptions,
        callback: (Result<PgCameraPosition?>) -> Unit,
    ) = call(callback, { it as PgCameraPosition? }) { map.mapUpdate(options, it) }

    override fun cameraAnimate(
        cameraUpdate: PgCameraUpdate,
        duration: Long?,
        callback: (Result<Boolean?>) -> Unit,
    ) = call(callback, { it as Boolean? }) { map.cameraAnimate(cameraUpdate, duration, it) }

    override fun cameraMove(cameraUpdate: PgCameraUpdate, callback: (Result<Boolean?>) -> Unit) =
        call(callback, { it as Boolean? }) { map.cameraMove(cameraUpdate, it) }

    override fun mapUpdateMyLocationTrackingMode(
        mode: PgMyLocationTrackingMode,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.mapUpdateMyLocationTrackingMode(mode, it) }

    override fun locationComponentSetTrackingCameraOptions(
        tilt: Double,
        duration: Long?,
        callback: (Result<Boolean?>) -> Unit,
    ) = call(callback, { it as Boolean? }) {
        map.locationComponentSetTrackingCameraOptions(tilt, duration, it)
    }

    override fun locationComponentSetManualLocation(
        update: PgManualLocationUpdate,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.locationComponentSetManualLocation(update, it) }

    override fun mapMatchMapLanguageWithDeviceDefault(callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapMatchMapLanguageWithDeviceDefault(it) }

    override fun mapUpdateContentInsets(
        insets: PgEdgeInsets,
        animated: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.mapUpdateContentInsets(insets, animated, it) }

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
        cameraUpdate: PgCameraUpdate,
        duration: Long?,
        interpolation: PgCameraAnimationInterpolation?,
        callback: (Result<Boolean>) -> Unit,
    ) = call(callback, { it as Boolean }) {
        map.cameraEase(cameraUpdate, duration, interpolation, it)
    }

    override fun mapQueryCameraPosition(callback: (Result<PgCameraPosition>) -> Unit) =
        call(callback, { it as PgCameraPosition }) { map.mapQueryCameraPosition(it) }

    override fun mapEditGeoJsonSource(
        id: String,
        data: String,
        callback: (Result<Boolean>) -> Unit,
    ) = call(callback, { it as Boolean }) { map.mapEditGeoJsonSource(id, data, it) }

    override fun mapEditGeoJsonUrl(id: String, url: String, callback: (Result<Boolean>) -> Unit) =
        call(callback, { it as Boolean }) { map.mapEditGeoJsonUrl(id, url, it) }

    override fun mapSetLayerFilter(
        id: String,
        filter: String,
        callback: (Result<Boolean>) -> Unit,
    ) = call(callback, { it as Boolean }) { map.mapSetLayerFilter(id, filter, it) }

    // Answered with the style JSON, or null without a style.
    override fun mapGetStyle(callback: (Result<String?>) -> Unit) =
        call(callback, { it as String? }) { map.mapGetStyle(it) }

    override fun mapSetCustomHeaders(
        headers: Map<String, String>,
        filter: List<String>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.mapSetCustomHeaders(headers, filter, it) }

    override fun mapGetCustomHeaders(callback: (Result<Map<String, String>>) -> Unit) =
        call(callback, ::stringMap) { map.mapGetCustomHeaders(it) }

    // The feature queries answer each feature as its own JSON text.
    override fun mapQueryRenderedFeaturesAtPoint(
        x: Double,
        y: Double,
        layerIds: List<String>,
        filter: String?,
        callback: (Result<List<String>>) -> Unit,
    ) = call(callback, ::strings) {
        map.mapQueryRenderedFeaturesAtPoint(x, y, layerIds, filter, it)
    }

    override fun mapQueryRenderedFeaturesInRect(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        layerIds: List<String>,
        filter: String?,
        callback: (Result<List<String>>) -> Unit,
    ) = call(callback, ::strings) {
        map.mapQueryRenderedFeaturesInRect(left, top, right, bottom, layerIds, filter, it)
    }

    override fun mapQuerySourceFeatures(
        sourceId: String,
        sourceLayerId: String?,
        filter: String?,
        callback: (Result<List<String>>) -> Unit,
    ) = call(callback, ::strings) {
        map.mapQuerySourceFeatures(sourceId, sourceLayerId, filter, it)
    }

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
        callback: (Result<List<String>>) -> Unit,
    ) = call(callback, ::strings) { map.sourceGetClusterChildren(sourceId, clusterId, it) }

    override fun sourceGetClusterLeaves(
        sourceId: String,
        clusterId: Long,
        limit: Long,
        offset: Long,
        callback: (Result<List<String>>) -> Unit,
    ) = call(callback, ::strings) {
        map.sourceGetClusterLeaves(sourceId, clusterId, limit, offset, it)
    }

    override fun mapInvalidateAmbientCache(callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapInvalidateAmbientCache(it) }

    override fun mapClearAmbientCache(callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.mapClearAmbientCache(it) }

    override fun locationComponentGetLastLocation(callback: (Result<PgLatLng>) -> Unit) =
        call(callback, { it as PgLatLng }) { map.locationComponentGetLastLocation(it) }

    override fun mapGetVisibleRegion(callback: (Result<PgLatLngBounds>) -> Unit) =
        call(callback, { it as PgLatLngBounds }) { map.mapGetVisibleRegion(it) }

    override fun styleAddImage(
        name: String,
        bytes: ByteArray,
        length: Long,
        sdf: Boolean,
        pixelRatio: Double?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.styleAddImage(name, bytes, length, sdf, pixelRatio, it) }

    override fun styleAddImageSource(
        imageSourceId: String,
        bytes: ByteArray,
        length: Long,
        coordinates: PgLatLngQuad,
        callback: (Result<Unit>) -> Unit,
    ) = addSource(imageSourceId, callback) {
        map.styleAddImageSource(imageSourceId, bytes, length, coordinates, it)
    }

    override fun styleUpdateImageSource(
        imageSourceId: String,
        bytes: ByteArray?,
        length: Long?,
        coordinates: PgLatLngQuad?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.styleUpdateImageSource(imageSourceId, bytes, length, coordinates, it) }

    override fun mapToScreenLocation(
        latitude: Double,
        longitude: Double,
        callback: (Result<PgScreenPoint>) -> Unit,
    ) = call(callback, { it as PgScreenPoint }) { map.mapToScreenLocation(latitude, longitude, it) }

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
    ) = addLayer(imageLayerId, callback) {
        map.styleAddLayer(imageLayerId, imageSourceId, minzoom, maxzoom, it)
    }

    override fun styleAddLayerBelow(
        imageLayerId: String,
        imageSourceId: String,
        belowLayerId: String,
        minzoom: Double?,
        maxzoom: Double?,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(imageLayerId, callback) {
        map.styleAddLayerBelow(imageLayerId, imageSourceId, belowLayerId, minzoom, maxzoom, it)
    }

    override fun styleRemoveLayer(layerId: String, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.styleRemoveLayer(layerId, it) }

    override fun styleMoveLayer(
        layerId: String,
        belowLayerId: String?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.styleMoveLayer(layerId, belowLayerId, it) }

    override fun styleSetFilter(
        layerId: String,
        filter: String?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.styleSetFilter(layerId, filter, it) }

    // Answered with the filter JSON, or null when the layer has none.
    override fun styleGetFilter(layerId: String, callback: (Result<String?>) -> Unit) =
        call(callback, { it as String? }) { map.styleGetFilter(layerId, it) }

    override fun mapToLatLng(x: Double, y: Double, callback: (Result<PgLatLng>) -> Unit) =
        call(callback, { it as PgLatLng }) { map.mapToLatLng(x, y, it) }

    override fun mapGetMetersPerPixelAtLatitude(
        latitude: Double,
        callback: (Result<Double>) -> Unit,
    ) = call(callback, { it as Double }) { map.mapGetMetersPerPixelAtLatitude(latitude, it) }

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
        filter: String?,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.symbolLayerAdd(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter,
            enableInteraction, properties, it,
        )
    }

    override fun lineLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.lineLayerAdd(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter,
            enableInteraction, properties, it,
        )
    }

    override fun layerSetProperties(
        layerId: String,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.layerSetProperties(layerId, properties, it) }

    override fun circleLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.circleLayerAdd(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter,
            enableInteraction, properties, it,
        )
    }

    override fun fillLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.fillLayerAdd(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter,
            enableInteraction, properties, it,
        )
    }

    override fun fillExtrusionLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Boolean,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.fillExtrusionLayerAdd(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter,
            enableInteraction, properties, it,
        )
    }

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
    ) = addLayer(layerId, callback) {
        map.rasterLayerAdd(sourceId, layerId, belowLayerId, minzoom, maxzoom, properties, it)
    }

    override fun hillshadeLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.hillshadeLayerAdd(sourceId, layerId, belowLayerId, minzoom, maxzoom, properties, it)
    }

    override fun colorReliefLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.colorReliefLayerAdd(sourceId, layerId, belowLayerId, minzoom, maxzoom, properties, it)
    }

    override fun backgroundLayerAdd(
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.backgroundLayerAdd(layerId, belowLayerId, minzoom, maxzoom, properties, it)
    }

    override fun heatmapLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        properties: Map<String, Any?>,
        callback: (Result<Unit>) -> Unit,
    ) = addLayer(layerId, callback) {
        map.heatmapLayerAdd(
            sourceId, layerId, belowLayerId, sourceLayer, minzoom, maxzoom, filter, properties, it,
        )
    }

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

    // Answered with the state JSON, or null when the feature has none.
    override fun sourceGetFeatureState(
        sourceId: String,
        featureId: String,
        sourceLayer: String?,
        callback: (Result<String?>) -> Unit,
    ) = call(callback, { it as String? }) {
        map.sourceGetFeatureState(sourceId, featureId, sourceLayer, it)
    }

    override fun styleSetLight(light: Map<String, Any?>, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.styleSetLight(light, it) }

    override fun layerSetVisibility(
        layerId: String,
        visible: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.layerSetVisibility(layerId, visible, it) }

    // Answered with the ids that matched no layer.
    override fun layerSetVisibilityBatch(
        layerIds: List<String>,
        visible: Boolean,
        callback: (Result<List<String>?>) -> Unit,
    ) = call(callback, { reply -> reply?.let(::strings) }) {
        map.layerSetVisibilityBatch(layerIds, visible, it)
    }

    override fun layerSetZoomRange(
        layerId: String,
        minzoom: Double,
        maxzoom: Double,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) { map.layerSetZoomRange(layerId, minzoom, maxzoom, it) }

    override fun layerGetVisibility(layerId: String, callback: (Result<Boolean?>) -> Unit) =
        call(callback, { it as Boolean? }) { map.layerGetVisibility(layerId, it) }

    // Answered with the PNG bytes.
    override fun mapTakeSnapshot(
        width: Long?,
        height: Long?,
        callback: (Result<ByteArray?>) -> Unit,
    ) = call(callback, { it as ByteArray? }) { map.mapTakeSnapshot(width, height, it) }

    override fun styleGetLayerIds(callback: (Result<List<String>>) -> Unit) =
        call(callback, ::strings) { map.styleGetLayerIds(it) }

    override fun styleGetSourceIds(callback: (Result<List<String>>) -> Unit) =
        call(callback, ::strings) { map.styleGetSourceIds(it) }

    // Answered with the style-spec JSON, or null when there is no such layer.
    override fun styleGetLayerProperties(layerId: String, callback: (Result<String?>) -> Unit) =
        call(callback, { it as String? }) { map.styleGetLayerProperties(layerId, it) }

    // Answered with the style-spec JSON, or null when there is no such source.
    override fun styleGetSourceProperties(sourceId: String, callback: (Result<String?>) -> Unit) =
        call(callback, { it as String? }) { map.styleGetSourceProperties(sourceId, it) }

    override fun styleSetStyle(style: String, callback: (Result<Unit>) -> Unit) =
        unit(callback) { map.styleSetStyle(style, it) }

    /** Runs [body], which needs the map, for a call that answers nothing. */
    private fun unit(callback: (Result<Unit>) -> Unit, body: (MethodChannel.Result) -> Unit) =
        withMap(PigeonMethodResult.unit(callback), body)

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
     * Runs [body], which adds a layer, unless [layerId] is taken: the map then
     * answers LAYER_ALREADY_EXISTS.
     */
    private fun addLayer(
        layerId: String,
        callback: (Result<Unit>) -> Unit,
        body: (MethodChannel.Result) -> Unit,
    ) = unit(callback) {
        if (!map.rejectDuplicateLayerId(layerId, it)) {
            body(it)
        }
    }

    /**
     * Runs [body], which adds a source, unless [sourceId] is taken: the map
     * then answers SOURCE_ALREADY_EXISTS.
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
     * Runs [body] with [result] and answers what it throws with code "error",
     * as Pigeon does not catch the exceptions of an asynchronous handler.
     */
    private fun answer(result: MethodChannel.Result, body: (MethodChannel.Result) -> Unit) {
        try {
            body(result)
        } catch (e: RuntimeException) {
            Log.e(TAG, "A map call failed", e)
            result.error("error", e.message, Log.getStackTraceString(e))
        }
    }

    companion object {
        private const val TAG = "MapHostApi"
        private const val MAP_NOT_READY = "MAP_NOT_READY"
        private const val MAP_NOT_READY_MESSAGE =
            "Map is not ready (activity may have been recreated)"
    }
}

/** Casts [reply] to the List<String> Pigeon sends. */
private fun strings(reply: Any?): List<String> = (reply as List<*>).map { it as String }

/** Copies [reply] into a new Map<String, String>. */
private fun stringMap(reply: Any?): Map<String, String> =
    (reply as Map<*, *>).entries.associate { (key, value) -> key as String to value as String }
