// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package com.mapbox.mapboxgl

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.AssetFileDescriptor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.PointF
import android.graphics.RectF
import android.location.Location
import android.os.Build
import android.os.Process
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonParser
import com.mapbox.android.gestures.AndroidGesturesManager
import com.mapbox.android.gestures.MoveGestureDetector
import com.mapbox.android.gestures.MoveGestureDetector.OnMoveGestureListener
import com.mapbox.geojson.Feature
import com.mapbox.geojson.FeatureCollection
import com.mapbox.mapboxgl.MapboxMapsPlugin.LifecycleProvider
import com.mapbox.mapboxsdk.camera.CameraPosition
import com.mapbox.mapboxsdk.camera.CameraUpdate
import com.mapbox.mapboxsdk.camera.CameraUpdateFactory.newLatLngBounds
import com.mapbox.mapboxsdk.camera.CameraUpdateFactory.paddingTo
import com.mapbox.mapboxsdk.constants.MapboxConstants
import com.mapbox.mapboxsdk.geometry.LatLng
import com.mapbox.mapboxsdk.geometry.LatLngBounds
import com.mapbox.mapboxsdk.geometry.LatLngQuad
import com.mapbox.mapboxsdk.location.LocationComponent
import com.mapbox.mapboxsdk.location.LocationComponentActivationOptions
import com.mapbox.mapboxsdk.location.LocationComponentOptions
import com.mapbox.mapboxsdk.location.OnCameraTrackingChangedListener
import com.mapbox.mapboxsdk.location.engine.LocationEngineCallback
import com.mapbox.mapboxsdk.location.engine.LocationEngineResult
import com.mapbox.mapboxsdk.location.modes.CameraMode
import com.mapbox.mapboxsdk.location.modes.RenderMode
import com.mapbox.mapboxsdk.maps.MapView
import com.mapbox.mapboxsdk.maps.MapView.OnDidBecomeIdleListener
import com.mapbox.mapboxsdk.maps.MapboxMap
import com.mapbox.mapboxsdk.maps.MapboxMap.CancelableCallback
import com.mapbox.mapboxsdk.maps.MapboxMap.OnCameraIdleListener
import com.mapbox.mapboxsdk.maps.MapboxMap.OnCameraMoveListener
import com.mapbox.mapboxsdk.maps.MapboxMap.OnCameraMoveStartedListener
import com.mapbox.mapboxsdk.maps.MapboxMap.OnMapClickListener
import com.mapbox.mapboxsdk.maps.MapboxMap.OnMapLongClickListener
import com.mapbox.mapboxsdk.maps.MapboxMapOptions
import com.mapbox.mapboxsdk.maps.OnMapReadyCallback
import com.mapbox.mapboxsdk.maps.Style
import com.mapbox.mapboxsdk.maps.Style.OnStyleLoaded
import com.mapbox.mapboxsdk.offline.OfflineManager
import com.mapbox.mapboxsdk.offline.OfflineManager.Companion.getInstance
import com.mapbox.mapboxsdk.style.expressions.Expression
import com.mapbox.mapboxsdk.style.layers.CircleLayer
import com.mapbox.mapboxsdk.style.layers.FillExtrusionLayer
import com.mapbox.mapboxsdk.style.layers.FillLayer
import com.mapbox.mapboxsdk.style.layers.HeatmapLayer
import com.mapbox.mapboxsdk.style.layers.HillshadeLayer
import com.mapbox.mapboxsdk.style.layers.LineLayer
import com.mapbox.mapboxsdk.style.layers.Property
import com.mapbox.mapboxsdk.style.layers.PropertyFactory
import com.mapbox.mapboxsdk.style.layers.PropertyValue
import com.mapbox.mapboxsdk.style.layers.RasterLayer
import com.mapbox.mapboxsdk.style.layers.SymbolLayer
import com.mapbox.mapboxsdk.style.sources.CustomGeometrySource
import com.mapbox.mapboxsdk.style.sources.GeoJsonSource
import com.mapbox.mapboxsdk.style.sources.ImageSource
import com.mapbox.mapboxsdk.style.sources.VectorSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView
import java.io.IOException
import java.io.InputStream
import java.util.Locale
import kotlin.math.ceil

@SuppressLint("MissingPermission")
/** Controller of a single MapboxMaps MapView instance.  */
internal class MapboxMapController(
    id: Int,
    private val context: Context,
    messenger: BinaryMessenger,
    private val lifecycleProvider: LifecycleProvider,
    options: MapboxMapOptions,
    private val styleStringInitial: String,
    dragEnabled: Boolean
) : DefaultLifecycleObserver, OnCameraIdleListener, OnCameraMoveListener,
    OnCameraMoveStartedListener, OnDidBecomeIdleListener, OnMapClickListener,
    OnMapLongClickListener, MapboxMapOptionsSink, MethodCallHandler, OnMapReadyCallback,
    OnCameraTrackingChangedListener, PlatformView {

    private val methodChannel: MethodChannel =
        MethodChannel(messenger, "plugins.flutter.io/mapbox_maps_$id")

    private val density: Float = context.resources.displayMetrics.density

    private var mapView: MapView? = MapView(context, options)

    /**
     * This container is returned as the final platform view instead of returning `mapView`.
     * See [MapboxMapController.destroyMapViewIfNecessary] for details.
     */
    private val mapViewContainer: FrameLayout = FrameLayout(context)
    private var mapboxMap: MapboxMap? = null
    private var trackCameraPosition = false
    private var myLocationEnabled = false
    private var myLocationTrackingMode = 0
    private var myLocationRenderMode = 0
    private var disposed = false
    private var mapReadyResult: MethodChannel.Result? = null
    private var locationComponent: LocationComponent? = null
    private var locationEngineCallback: LocationEngineCallback<LocationEngineResult>? = null
    private var style: Style? = null
    private var draggedFeature: Feature? = null
    private var androidGesturesManager: AndroidGesturesManager? = null
    private var dragOrigin: LatLng? = null
    private var dragPrevious: LatLng? = null
    private val interactiveFeatureLayerIds = HashSet<String>()
    private val addedFeaturesByLayer = HashMap<String, FeatureCollection>()
    private var bounds: LatLngBounds? = null

    private var onStyleLoadedCallback = OnStyleLoaded { style ->
        this@MapboxMapController.style = style

        updateMyLocationEnabled()
        if (null != bounds) {
            mapboxMap!!.setLatLngBoundsForCameraTarget(bounds)
        }
        mapboxMap!!.addOnMapClickListener(this@MapboxMapController)
        mapboxMap!!.addOnMapLongClickListener(this@MapboxMapController)
        methodChannel.invokeMethod("map#onStyleLoaded", null)
    }

    init {
        MapBoxUtils.getMapbox(context)

        if (dragEnabled) {
            androidGesturesManager = AndroidGesturesManager(mapView!!.context, false)
        }
        mapViewContainer.addView(mapView)
        methodChannel.setMethodCallHandler(this)

        lifecycleProvider.lifecycle!!.addObserver(this)
        mapView!!.getMapAsync(this)
    }

    override fun getView(): View {
        return mapViewContainer
    }

    private val cameraPosition: CameraPosition?
        get() = if (trackCameraPosition) mapboxMap!!.cameraPosition else null

    override fun onMapReady(mapboxMap: MapboxMap) {
        this.mapboxMap = mapboxMap
        if (mapReadyResult != null) {
            mapReadyResult!!.success(null)
            mapReadyResult = null
        }
        mapboxMap.addOnCameraMoveStartedListener(this)
        mapboxMap.addOnCameraMoveListener(this)
        mapboxMap.addOnCameraIdleListener(this)
        if (androidGesturesManager != null) {
            androidGesturesManager!!.setMoveGestureListener(MoveGestureListener())
            mapView!!.setOnTouchListener { _, event ->
                androidGesturesManager!!.onTouchEvent(event)
                draggedFeature != null
            }
        }
        mapView!!.addOnStyleImageMissingListener { id: String ->
            val displayMetrics = context.resources.displayMetrics
            val bitmap = getScaledImage(id, displayMetrics.density)
            if (bitmap != null) {
                mapboxMap.style!!.addImage(id, bitmap)
            }
        }
        mapView!!.addOnDidBecomeIdleListener(this)
        setStyleString(styleStringInitial)
    }

    override fun setStyleString(styleString: String) {
        clearLocationComponentLayer()
        styleString.trim().let { style ->

            // Check if json, url, absolute path or asset path:
            if (style.isEmpty()) {
                Log.e(TAG, "setStyleString - string empty or null")
            } else if (style.startsWith("{") || style.startsWith("[")) {
                mapboxMap!!.setStyle(Style.Builder().fromJson(style), onStyleLoadedCallback)
            } else if (style.startsWith("/")) {
                // Absolute path
                mapboxMap!!.setStyle(
                    Style.Builder().fromUri("file://$style"), onStyleLoadedCallback
                )
            } else if (!style.startsWith("http://")
                && !style.startsWith("https://")
                && !style.startsWith("mapbox://")
            ) {
                // We are assuming that the style will be loaded from an asset here.
                val key = MapboxMapsPlugin.flutterAssets.getAssetFilePathByName(style)
                mapboxMap!!.setStyle(Style.Builder().fromUri("asset://$key"), onStyleLoadedCallback)
            } else {
                mapboxMap!!.setStyle(Style.Builder().fromUri(style), onStyleLoadedCallback)
            }
        }
    }

    private fun enableLocationComponent(style: Style) {
        if (hasLocationPermission()) {
            locationComponent = mapboxMap!!.locationComponent
            val options = LocationComponentActivationOptions
                .builder(context, style)
                .locationComponentOptions(buildLocationComponentOptions(style))
                .build()
            locationComponent!!.activateLocationComponent(options)
            locationComponent!!.isLocationComponentEnabled = true
            locationComponent!!.setMaxAnimationFps(30)
            updateMyLocationTrackingMode()
            updateMyLocationRenderMode()
            locationComponent!!.addOnCameraTrackingChangedListener(this)
        } else {
            Log.e(TAG, "missing location permissions")
        }
    }

    private fun updateLocationComponentLayer() {
        if (locationComponent != null && locationComponentRequiresUpdate()) {
            locationComponent!!.applyStyle(buildLocationComponentOptions(style))
        }
    }

    private fun clearLocationComponentLayer() {
        if (locationComponent != null) {
            locationComponent!!.applyStyle(buildLocationComponentOptions(null))
        }
    }

    private fun getLastLayerOnStyle(style: Style?): String? {
        if (style != null) {
            val layers = style.layers
            if (layers.size > 0) {
                return layers[layers.size - 1].id
            }
        }
        return null
    }

    /// only update if the last layer is not the mapbox-location-bearing-layer
    private fun locationComponentRequiresUpdate(): Boolean {
        val lastLayerId = getLastLayerOnStyle(style)
        return lastLayerId != null && lastLayerId != "mapbox-location-bearing-layer"
    }

    private fun buildLocationComponentOptions(style: Style?): LocationComponentOptions {
        val optionsBuilder = LocationComponentOptions.builder(context)
        optionsBuilder.trackingGesturesManagement(true)
        val lastLayerId = getLastLayerOnStyle(style)
        if (lastLayerId != null) {
            optionsBuilder.layerAbove(lastLayerId)
        }
        return optionsBuilder.build()
    }

    private fun onUserLocationUpdate(location: Location?) {
        if (location == null) {
            return
        }

        val userLocation = mutableMapOf(
            "position" to doubleArrayOf(location.latitude, location.longitude),
            "speed" to location.speed,
            "altitude" to location.altitude,
            "bearing" to location.bearing,
            "horizontalAccuracy" to location.accuracy,
            "timestamp" to location.time,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            userLocation["verticalAccuracy"] = location.verticalAccuracyMeters
        }

        val arguments = mapOf("userLocation" to userLocation)

        methodChannel.invokeMethod("map#onUserLocationUpdated", arguments)
    }

    private fun addGeoJsonSource(sourceName: String, source: String) {
        val featureCollection = FeatureCollection.fromJson(source)
        val geoJsonSource = GeoJsonSource(sourceName, featureCollection)
        addedFeaturesByLayer[sourceName] = featureCollection
        style!!.addSource(geoJsonSource)
    }

    private fun setGeoJsonSource(sourceName: String, geojson: String) {
        val featureCollection = FeatureCollection.fromJson(geojson)
        val geoJsonSource = style!!.getSourceAs<GeoJsonSource>(sourceName)
        addedFeaturesByLayer[sourceName] = featureCollection
        geoJsonSource!!.setGeoJson(featureCollection)
    }

    private fun setGeoJsonFeature(sourceName: String, geojsonFeature: String) {
        val feature = Feature.fromJson(geojsonFeature)
        val featureCollection = addedFeaturesByLayer[sourceName]
        val geoJsonSource = style!!.getSourceAs<GeoJsonSource>(sourceName)
        if (featureCollection != null && geoJsonSource != null) {
            val features = featureCollection.features()
            for (i in features!!.indices) {
                val id = features[i].id()
                if (id == feature.id()) {
                    features[i] = feature
                    break
                }
            }
            geoJsonSource.setGeoJson(featureCollection)
        }
    }

    private fun addSymbolLayer(
        layerId: String,
        sourceId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minZoom: Float?,
        maxZoom: Float?,
        properties: Array<PropertyValue<*>>,
        enableInteraction: Boolean,
        filter: Expression?
    ) {
        val symbolLayer = SymbolLayer(layerId, sourceId)
        symbolLayer.setProperties(*properties)
        if (sourceLayer != null) {
            symbolLayer.sourceLayer = sourceLayer
        }
        if (minZoom != null) {
            symbolLayer.minZoom = minZoom
        }
        if (maxZoom != null) {
            symbolLayer.maxZoom = maxZoom
        }
        if (filter != null) {
            symbolLayer.setFilter(filter)
        }
        if (belowLayerId != null) {
            style!!.addLayerBelow(symbolLayer, belowLayerId)
        } else {
            style!!.addLayer(symbolLayer)
        }
        if (enableInteraction) {
            interactiveFeatureLayerIds.add(layerId)
        }
    }

    private fun addLineLayer(
        layerId: String,
        sourceId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minZoom: Float?,
        maxZoom: Float?,
        properties: Array<PropertyValue<*>>,
        enableInteraction: Boolean,
        filter: Expression?
    ) {
        val lineLayer = LineLayer(layerId, sourceId)
        lineLayer.setProperties(*properties)
        if (sourceLayer != null) {
            lineLayer.sourceLayer = sourceLayer
        }
        if (minZoom != null) {
            lineLayer.minZoom = minZoom
        }
        if (maxZoom != null) {
            lineLayer.maxZoom = maxZoom
        }
        if (filter != null) {
            lineLayer.setFilter(filter)
        }
        if (belowLayerId != null) {
            style!!.addLayerBelow(lineLayer, belowLayerId)
        } else {
            style!!.addLayer(lineLayer)
        }
        if (enableInteraction) {
            interactiveFeatureLayerIds.add(layerId)
        }
    }

    private fun addFillLayer(
        layerId: String,
        sourceId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minZoom: Float?,
        maxZoom: Float?,
        properties: Array<PropertyValue<*>>,
        enableInteraction: Boolean,
        filter: Expression?
    ) {
        val fillLayer = FillLayer(layerId, sourceId)
        fillLayer.setProperties(*properties)
        if (sourceLayer != null) {
            fillLayer.sourceLayer = sourceLayer
        }
        if (minZoom != null) {
            fillLayer.minZoom = minZoom
        }
        if (maxZoom != null) {
            fillLayer.maxZoom = maxZoom
        }
        if (filter != null) {
            fillLayer.setFilter(filter)
        }
        if (belowLayerId != null) {
            style!!.addLayerBelow(fillLayer, belowLayerId)
        } else {
            style!!.addLayer(fillLayer)
        }
        if (enableInteraction) {
            interactiveFeatureLayerIds.add(layerId)
        }
    }

    private fun addCircleLayer(
        layerId: String,
        sourceId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minZoom: Float?,
        maxZoom: Float?,
        properties: Array<PropertyValue<*>>,
        enableInteraction: Boolean,
        filter: Expression?
    ) {
        val circleLayer = CircleLayer(layerId, sourceId)
        circleLayer.setProperties(*properties)
        if (sourceLayer != null) {
            circleLayer.sourceLayer = sourceLayer
        }
        if (minZoom != null) {
            circleLayer.minZoom = minZoom
        }
        if (maxZoom != null) {
            circleLayer.maxZoom = maxZoom
        }
        if (filter != null) {
            circleLayer.setFilter(filter)
        }
        if (belowLayerId != null) {
            style!!.addLayerBelow(circleLayer, belowLayerId)
        } else {
            style!!.addLayer(circleLayer)
        }
        if (enableInteraction) {
            interactiveFeatureLayerIds.add(layerId)
        }
    }

    private fun parseFilter(filter: String?): Expression? {
        val filterJsonElement = JsonParser.parseString(filter)
        return if (filterJsonElement.isJsonNull) {
            null
        } else {
            Expression.Converter.convert(filterJsonElement)
        }
    }

    private fun addRasterLayer(
        layerId: String,
        sourceId: String,
        minZoom: Float?,
        maxZoom: Float?,
        belowLayerId: String?,
        properties: Array<PropertyValue<*>>,
    ) {
        val layer = RasterLayer(layerId, sourceId)
        layer.setProperties(*properties)
        if (minZoom != null) {
            layer.minZoom = minZoom
        }
        if (maxZoom != null) {
            layer.maxZoom = maxZoom
        }
        if (belowLayerId != null) {
            style!!.addLayerBelow(layer, belowLayerId)
        } else {
            style!!.addLayer(layer)
        }
    }

    private fun addHillshadeLayer(
        layerId: String,
        sourceId: String,
        minZoom: Float?,
        maxZoom: Float?,
        belowLayerId: String?,
        properties: Array<PropertyValue<*>>,
    ) {
        val layer = HillshadeLayer(layerId, sourceId)
        layer.setProperties(*properties)
        if (minZoom != null) {
            layer.minZoom = minZoom
        }
        if (maxZoom != null) {
            layer.maxZoom = maxZoom
        }
        if (belowLayerId != null) {
            style!!.addLayerBelow(layer, belowLayerId)
        } else {
            style!!.addLayer(layer)
        }
    }

    private fun firstFeatureOnLayers(`in`: RectF): Feature? {
        if (style != null) {
            val layers = style!!.layers
            val layersInOrder: MutableList<String?> = ArrayList()
            for (layer in layers) {
                val id = layer.id
                if (interactiveFeatureLayerIds.contains(id)) layersInOrder.add(id)
            }
            layersInOrder.reverse()
            for (id in layersInOrder) {
                val features = mapboxMap!!.queryRenderedFeatures(`in`, id)
                if (features.isNotEmpty()) {
                    return features[0]
                }
            }
        }
        return null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "map#waitForMap" -> {
                if (mapboxMap != null) {
                    result.success(null)
                    return
                }
                mapReadyResult = result
            }

            "map#update" -> {
                Convert.interpretMapboxMapOptions(call.argument("options"), this, context)
                result.success(Convert.toJson(cameraPosition))
            }

            "map#updateMyLocationTrackingMode" -> {
                val myLocationTrackingMode = call.argument<Int>("mode")!!
                setMyLocationTrackingMode(myLocationTrackingMode)
                result.success(null)
            }

            "map#matchMapLanguageWithDeviceDefault" -> {
                try {
                    val deviceLocale = Locale.getDefault()
                    mapboxMap!!.setMapLanguage(deviceLocale.language)
                    result.success(null)
                } catch (exception: RuntimeException) {
                    Log.d(TAG, exception.toString())
                    result.error("MAPBOX LOCALIZATION PLUGIN ERROR", exception.toString(), null)
                }
            }

            "map#updateContentInsets" -> {
                val insets = call.argument<HashMap<String, Any>>("bounds")!!
                val cameraUpdate = paddingTo(
                    Convert.toPixels(insets["left"], density).toDouble(),
                    Convert.toPixels(insets["top"], density).toDouble(),
                    Convert.toPixels(insets["right"], density).toDouble(),
                    Convert.toPixels(insets["bottom"], density).toDouble()
                )
                val animated = call.argument<Boolean?>("animated")!!

                if (animated) {
                    animateCamera(cameraUpdate, result)
                } else {
                    moveCamera(cameraUpdate, result)
                }
            }

            "map#setMapLanguage" -> {
                val language = call.argument<String>("language") as String
                try {
                    mapboxMap!!.setMapLanguage(language)
                    result.success(null)
                } catch (exception: RuntimeException) {
                    Log.d(TAG, exception.toString())
                    result.error("MAPBOX LOCALIZATION PLUGIN ERROR", exception.toString(), null)
                }
            }

            "map#getVisibleRegion" -> {
                val visibleRegion = mapboxMap!!.projection.visibleRegion

                val reply = mapOf(
                    "sw" to listOf(
                        visibleRegion.latLngBounds.getLatSouth(),
                        visibleRegion.latLngBounds.getLonWest()
                    ),
                    "ne" to listOf(
                        visibleRegion.latLngBounds.getLatNorth(),
                        visibleRegion.latLngBounds.getLonEast()
                    )
                )

                result.success(reply)
            }

            "map#toScreenLocation" -> {
                val latLng = LatLng(call.argument("latitude")!!, call.argument("longitude")!!)
                val pointf = mapboxMap!!.projection.toScreenLocation(latLng)
                val reply = mapOf("x" to pointf.x, "y" to pointf.y)

                result.success(reply)
            }

            "map#toScreenLocationBatch" -> {
                val param = call.argument<Any>("coordinates") as DoubleArray
                val reply = DoubleArray(param.size)
                var i = 0
                while (i < param.size) {
                    val pointf =
                        mapboxMap!!.projection.toScreenLocation(LatLng(param[i], param[i + 1]))
                    reply[i] = pointf.x.toDouble()
                    reply[i + 1] = pointf.y.toDouble()
                    i += 2
                }
                result.success(reply)
            }

            "map#toLatLng" -> {
                val reply: MutableMap<String, Any> = HashMap()
                val latlng = mapboxMap!!
                    .projection
                    .fromScreenLocation(
                        PointF(
                            (call.argument<Any>("x") as Double).toFloat(),
                            (call.argument<Any>("y") as Double).toFloat()
                        )
                    )
                mapOf("latitude" to latlng.latitude, "longitude" to latlng.longitude)

                result.success(reply)
            }

            "map#getMetersPerPixelAtLatitude" -> {
                val retVal = mapboxMap!!
                    .projection
                    .getMetersPerPixelAtLatitude((call.argument<Any>("latitude") as Double))
                val reply = mapOf("metersperpixel" to retVal)
                result.success(reply)
            }

            "camera#move" -> {
                val cameraUpdate =
                    Convert.toCameraUpdate(call.argument("cameraUpdate"), mapboxMap, density)
                if (cameraUpdate != null) {
                    // camera transformation not handled yet
                    mapboxMap!!.moveCamera(cameraUpdate,
                        object : OnCameraMoveFinishedListener() {
                            override fun onFinish() {
                                super.onFinish()
                                result.success(true)
                            }

                            override fun onCancel() {
                                super.onCancel()
                                result.success(false)
                            }
                        })
                } else {
                    result.success(false)
                }
            }

            "camera#animate" -> {
                val cameraUpdate =
                    Convert.toCameraUpdate(call.argument("cameraUpdate"), mapboxMap, density)
                val duration = call.argument<Int>("duration")
                val onCameraMoveFinishedListener: OnCameraMoveFinishedListener =
                    object : OnCameraMoveFinishedListener() {
                        override fun onFinish() {
                            super.onFinish()
                            result.success(true)
                        }

                        override fun onCancel() {
                            super.onCancel()
                            result.success(false)
                        }
                    }
                if (cameraUpdate != null && duration != null) {
                    // camera transformation not handled yet
                    mapboxMap!!.animateCamera(cameraUpdate, duration, onCameraMoveFinishedListener)
                } else if (cameraUpdate != null) {
                    // camera transformation not handled yet
                    mapboxMap!!.animateCamera(cameraUpdate, onCameraMoveFinishedListener)
                } else {
                    result.success(false)
                }
            }

            "map#queryRenderedFeatures" -> {
                val layerIds = (call.argument<Any>("layerIds") as List<String>).toTypedArray()
                val filter = call.argument<List<Any>>("filter")
                val jsonElement = if (filter == null) null else Gson().toJsonTree(filter)
                var jsonArray: JsonArray? = null
                if (jsonElement != null && jsonElement.isJsonArray) {
                    jsonArray = jsonElement.asJsonArray
                }
                val filterExpression =
                    if (jsonArray == null) null else Expression.Converter.convert(jsonArray)
                val features = if (call.hasArgument("x")) {
                    val x = call.argument<Double>("x")
                    val y = call.argument<Double>("y")
                    val pixel = PointF(x!!.toFloat(), y!!.toFloat())
                    mapboxMap!!.queryRenderedFeatures(pixel, filterExpression, *layerIds)
                } else {
                    val left = call.argument<Double>("left")
                    val top = call.argument<Double>("top")
                    val right = call.argument<Double>("right")
                    val bottom = call.argument<Double>("bottom")
                    val rectF = RectF(
                        left!!.toFloat(), top!!.toFloat(), right!!.toFloat(), bottom!!.toFloat()
                    )
                    mapboxMap!!.queryRenderedFeatures(rectF, filterExpression, *layerIds)
                }
                val featuresJson: MutableList<String> = ArrayList()
                for (feature in features) {
                    featuresJson.add(feature.toJson())
                }
                result.success(mapOf("features" to featuresJson))
            }

            "map#setTelemetryEnabled" -> {
                result.success(null)
            }

            "map#getTelemetryEnabled" -> {
                result.success(false)
            }

            "map#invalidateAmbientCache" -> {
                val fileSource = getInstance(context)
                fileSource.invalidateAmbientCache(
                    object : OfflineManager.FileSourceCallback {
                        override fun onSuccess() {
                            result.success(null)
                        }

                        override fun onError(message: String) {
                            result.error("MAPBOX CACHE ERROR", message, null)
                        }
                    })
            }

            "source#addGeoJson" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val geojson = call.argument<String>("geojson")!!
                addGeoJsonSource(sourceId, geojson)
                result.success(null)
            }

            "source#setGeoJson" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val geojson = call.argument<String>("geojson")!!
                setGeoJsonSource(sourceId, geojson)
                result.success(null)
            }

            "source#setFeature" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val geojsonFeature = call.argument<String>("geojsonFeature")!!
                setGeoJsonFeature(sourceId, geojsonFeature)
                result.success(null)
            }

            "symbolLayer#add" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val layerId = call.argument<String>("layerId")!!
                val belowLayerId = call.argument<String>("belowLayerId")
                val sourceLayer = call.argument<String>("sourceLayer")
                val minzoom = call.argument<Double>("minzoom")
                val maxzoom = call.argument<Double>("maxzoom")
                val filter = call.argument<String>("filter")
                val enableInteraction = call.argument<Boolean>("enableInteraction")!!
                val properties =
                    LayerPropertyConverter.interpretSymbolLayerProperties(call.argument("properties"))
                val filterExpression = parseFilter(filter)
                addSymbolLayer(
                    layerId,
                    sourceId,
                    belowLayerId,
                    sourceLayer,
                    minzoom?.toFloat(),
                    maxzoom?.toFloat(),
                    properties,
                    enableInteraction,
                    filterExpression
                )
                updateLocationComponentLayer()
                result.success(null)
            }

            "lineLayer#add" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val layerId = call.argument<String>("layerId")!!
                val belowLayerId = call.argument<String>("belowLayerId")
                val sourceLayer = call.argument<String>("sourceLayer")
                val minzoom = call.argument<Double>("minzoom")
                val maxzoom = call.argument<Double>("maxzoom")
                val filter = call.argument<String>("filter")
                val enableInteraction = call.argument<Boolean>("enableInteraction")!!
                val properties =
                    LayerPropertyConverter.interpretLineLayerProperties(call.argument("properties"))
                val filterExpression = parseFilter(filter)
                addLineLayer(
                    layerId,
                    sourceId,
                    belowLayerId,
                    sourceLayer,
                    minzoom?.toFloat(),
                    maxzoom?.toFloat(),
                    properties,
                    enableInteraction,
                    filterExpression
                )
                updateLocationComponentLayer()
                result.success(null)
            }

            "fillLayer#add" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val layerId = call.argument<String>("layerId")!!
                val belowLayerId = call.argument<String>("belowLayerId")
                val sourceLayer = call.argument<String>("sourceLayer")
                val minzoom = call.argument<Double>("minzoom")
                val maxzoom = call.argument<Double>("maxzoom")
                val filter = call.argument<String>("filter")
                val enableInteraction = call.argument<Boolean>("enableInteraction")!!
                val properties =
                    LayerPropertyConverter.interpretFillLayerProperties(call.argument("properties"))
                val filterExpression = parseFilter(filter)
                addFillLayer(
                    layerId,
                    sourceId,
                    belowLayerId,
                    sourceLayer,
                    minzoom?.toFloat(),
                    maxzoom?.toFloat(),
                    properties,
                    enableInteraction,
                    filterExpression
                )
                updateLocationComponentLayer()
                result.success(null)
            }

            "circleLayer#add" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val layerId = call.argument<String>("layerId")!!
                val belowLayerId = call.argument<String>("belowLayerId")
                val sourceLayer = call.argument<String>("sourceLayer")
                val minzoom = call.argument<Double>("minzoom")
                val maxzoom = call.argument<Double>("maxzoom")
                val filter = call.argument<String>("filter")
                val enableInteraction = call.argument<Boolean>("enableInteraction")!!
                val properties =
                    LayerPropertyConverter.interpretCircleLayerProperties(call.argument("properties"))
                val filterExpression = parseFilter(filter)
                addCircleLayer(
                    layerId,
                    sourceId,
                    belowLayerId,
                    sourceLayer,
                    minzoom?.toFloat(),
                    maxzoom?.toFloat(),
                    properties,
                    enableInteraction,
                    filterExpression
                )
                updateLocationComponentLayer()
                result.success(null)
            }

            "rasterLayer#add" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val layerId = call.argument<String>("layerId")!!
                val belowLayerId = call.argument<String>("belowLayerId")
                val minzoom = call.argument<Double>("minzoom")
                val maxzoom = call.argument<Double>("maxzoom")
                val properties =
                    LayerPropertyConverter.interpretRasterLayerProperties(call.argument("properties"))
                addRasterLayer(
                    layerId,
                    sourceId,
                    minzoom?.toFloat(),
                    maxzoom?.toFloat(),
                    belowLayerId,
                    properties,
                )
                updateLocationComponentLayer()
                result.success(null)
            }

            "hillshadeLayer#add" -> {
                val sourceId = call.argument<String>("sourceId")!!
                val layerId = call.argument<String>("layerId")!!
                val belowLayerId = call.argument<String>("belowLayerId")
                val minzoom = call.argument<Double>("minzoom")
                val maxzoom = call.argument<Double>("maxzoom")
                val properties =
                    LayerPropertyConverter.interpretHillshadeLayerProperties(call.argument("properties"))
                addHillshadeLayer(
                    layerId,
                    sourceId,
                    minzoom?.toFloat(),
                    maxzoom?.toFloat(),
                    belowLayerId,
                    properties,
                )
                updateLocationComponentLayer()
                result.success(null)
            }

            "locationComponent#getLastLocation" -> {
                Log.e(TAG, "location component: getLastLocation")
                if (myLocationEnabled && locationComponent != null) {
                    mapboxMap!!.locationComponent.locationEngine!!.getLastLocation(
                        object : LocationEngineCallback<LocationEngineResult> {
                            override fun onSuccess(locationEngineResult: LocationEngineResult) {
                                val lastLocation = locationEngineResult.lastLocation
                                if (lastLocation != null) {
                                    val reply = mapOf(
                                        "latitude" to lastLocation.latitude,
                                        "longitude" to lastLocation.longitude,
                                        "altitude" to lastLocation.altitude
                                    )

                                    result.success(reply)
                                } else {
                                    result.error("", "", null) // ???
                                }
                            }

                            override fun onFailure(exception: Exception) {
                                result.error("", "", null) // ???
                            }
                        })
                }
            }

            "style#addImage" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                style!!.addImage(
                    call.argument("name")!!,
                    BitmapFactory.decodeByteArray(
                        call.argument("bytes"),
                        0,
                        call.argument("length")!!
                    ),
                    call.argument("sdf")!!
                )
                result.success(null)
            }

            "style#addImageSource" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                val coordinates = Convert.toLatLngList(call.argument("coordinates"), false)
                style!!.addSource(
                    ImageSource(
                        call.argument("imageSourceId"),
                        LatLngQuad(
                            coordinates[0],
                            coordinates[1],
                            coordinates[2],
                            coordinates[3]
                        ),
                        BitmapFactory.decodeByteArray(
                            call.argument("bytes"), 0, call.argument("length")!!
                        )
                    )
                )
                result.success(null)
            }

            "style#addSource" -> {
                val id = Convert.toString(call.argument("sourceId"))
                val properties = call.argument<Any>("properties") as Map<String, Any>?
                SourcePropertyConverter.addSource(id, properties, style)
                result.success(null)
            }

            "style#removeSource" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                style!!.removeSource((call.argument<Any>("sourceId") as String))
                result.success(null)
            }

            "style#addLayer" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                addRasterLayer(
                    call.argument("imageLayerId")!!,
                    call.argument("imageSourceId")!!,
                    if (call.argument<Any?>("minzoom") != null) (call.argument<Any>("minzoom") as Double?)!!.toFloat() else null,
                    if (call.argument<Any?>("maxzoom") != null) (call.argument<Any>("maxzoom") as Double?)!!.toFloat() else null,
                    null, arrayOf(),
                )
                result.success(null)
            }

            "style#addLayerBelow" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                addRasterLayer(
                    call.argument("imageLayerId")!!,
                    call.argument("imageSourceId")!!,
                    if (call.argument<Any?>("minzoom") != null) (call.argument<Any>("minzoom") as Double).toFloat() else null,
                    if (call.argument<Any?>("maxzoom") != null) (call.argument<Any>("maxzoom") as Double).toFloat() else null,
                    call.argument("belowLayerId"), arrayOf(),
                )
                result.success(null)
            }

            "style#removeLayer" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                val layerId = call.argument<String>("layerId")
                style!!.removeLayer(layerId!!)
                interactiveFeatureLayerIds.remove(layerId)
                result.success(null)
            }

            "map#setCameraBounds" -> {
                val west = call.argument<Double>("west")!!
                val north = call.argument<Double>("north")!!
                val south = call.argument<Double>("south")!!
                val east = call.argument<Double>("east")!!
                val padding = call.argument<Int>("padding")!!

                val latLngBounds: LatLngBounds = LatLngBounds.Builder()
                    .include(LatLng(north, east)) // Northeast
                    .include(LatLng(south, west))
                    .build()

                mapboxMap!!.easeCamera(newLatLngBounds(latLngBounds, padding), 200)
            }

            "style#setFilter" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                val layerId = call.argument<String>("layerId")!!
                val filter = call.argument<String>("filter")
                val layer = style!!.getLayer(layerId)
                val jsonElement = JsonParser.parseString(filter)
                val expression = Expression.Converter.convert(jsonElement)
                when (layer) {
                    is CircleLayer -> {
                        layer.setFilter(expression)
                    }

                    is FillExtrusionLayer -> {
                        layer.setFilter(expression)
                    }

                    is FillLayer -> {
                        layer.setFilter(expression)
                    }

                    is HeatmapLayer -> {
                        layer.setFilter(expression)
                    }

                    is LineLayer -> {
                        layer.setFilter(expression)
                    }

                    is SymbolLayer -> {
                        layer.setFilter(expression)
                    }

                    else -> {
                        result.error(
                            "INVALID LAYER TYPE",
                            String.format("Layer '%s' does not support filtering.", layerId),
                            null
                        )
                    }
                }
                result.success(null)
            }

            "style#getFilter" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }

                val layerId = call.argument<String>("layerId")!!

                val filter: Expression? = when (val layer = style!!.getLayer(layerId)) {
                    is CircleLayer -> layer.filter
                    is FillExtrusionLayer -> layer.filter
                    is FillLayer -> layer.filter
                    is HeatmapLayer -> layer.filter
                    is LineLayer -> layer.filter
                    is SymbolLayer -> layer.filter
                    else -> null
                }

                if (filter == null) {
                    result.error(
                        "INVALID LAYER TYPE",
                        String.format("Layer '%s' does not support filtering.", layerId),
                        null
                    )
                } else {
                    val reply = mapOf("filter" to filter.toString())
                    result.success(reply)
                }
            }

            "layer#setVisibility" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                val layerId = call.argument<String>("layerId")
                val visible = call.argument<Boolean>("visible")!!
                val layer = style!!.getLayer(layerId!!)
                layer!!.setProperties(PropertyFactory.visibility(if (visible) Property.VISIBLE else Property.NONE))
                result.success(null)
            }

            "map#querySourceFeatures" -> {
                val features: List<Feature>
                val sourceId = call.argument<Any>("sourceId") as String?
                val sourceLayerId = call.argument<Any>("sourceLayerId") as String?
                val filter = call.argument<List<Any>>("filter")
                val jsonElement = if (filter == null) null else Gson().toJsonTree(filter)
                var jsonArray: JsonArray? = null
                if (jsonElement != null && jsonElement.isJsonArray) {
                    jsonArray = jsonElement.asJsonArray
                }
                val filterExpression =
                    if (jsonArray == null) null else Expression.Converter.convert(jsonArray)
                val source = style!!.getSource(sourceId)
                features = if (source is GeoJsonSource) {
                    source.querySourceFeatures(filterExpression)
                } else if (source is CustomGeometrySource) {
                    source.querySourceFeatures(filterExpression)
                } else if (source is VectorSource && sourceLayerId != null) {
                    source.querySourceFeatures(arrayOf(sourceLayerId), filterExpression)
                } else {
                    emptyList()
                }
                val featuresJson: MutableList<String> = ArrayList()
                for (feature in features) {
                    featuresJson.add(feature.toJson())
                }
                result.success(mapOf("features" to featuresJson))
            }

            "style#getLayerIds" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                val layerIds: MutableList<String> = ArrayList()
                for (layer in style!!.layers) {
                    layerIds.add(layer.id)
                }
                val reply = mapOf("layers" to layerIds)
                result.success(reply)
            }

            "style#getSourceIds" -> {
                if (style == null) {
                    result.error(
                        "STYLE IS NULL",
                        "The style is null. Has onStyleLoaded() already been invoked?",
                        null
                    )
                }
                val sourceIds: MutableList<String> = ArrayList()
                for (source in style!!.sources) {
                    sourceIds.add(source.id)
                }

                val reply = mapOf("sources" to sourceIds)
                result.success(reply)
            }

            else -> result.notImplemented()
        }
    }

    override fun onCameraMoveStarted(reason: Int) {
        val isGesture = reason == OnCameraMoveStartedListener.REASON_API_GESTURE
        methodChannel.invokeMethod("camera#onMoveStarted", mapOf("isGesture" to isGesture))
    }

    override fun onCameraMove() {
        if (!trackCameraPosition) {
            return
        }
        val arguments = mapOf("position" to Convert.toJson(mapboxMap!!.cameraPosition))
        methodChannel.invokeMethod("camera#onMove", arguments)
    }

    override fun onCameraIdle() {
        val arguments = mutableMapOf<String, Any>()
        if (trackCameraPosition) {
            arguments["position"] = Convert.toJson(mapboxMap!!.cameraPosition)
        }
        methodChannel.invokeMethod("camera#onIdle", arguments)
    }

    override fun onCameraTrackingChanged(currentMode: Int) {
        val arguments = mapOf("mode" to currentMode)
        methodChannel.invokeMethod("map#onCameraTrackingChanged", arguments)
    }

    override fun onCameraTrackingDismissed() {
        myLocationTrackingMode = 0
        methodChannel.invokeMethod("map#onCameraTrackingDismissed", emptyMap<Any, Any>())
    }

    override fun onDidBecomeIdle() {
        methodChannel.invokeMethod("map#onIdle", emptyMap<Any, Any>())
    }

    override fun onMapClick(point: LatLng): Boolean {
        val pointf = mapboxMap!!.projection.toScreenLocation(point)
        val rectF = RectF(pointf.x - 10, pointf.y - 10, pointf.x + 10, pointf.y + 10)
        val feature = firstFeatureOnLayers(rectF)
        val arguments = mutableMapOf<String, Any?>(
            "x" to pointf.x,
            "y" to pointf.y,
            "lng" to point.longitude,
            "lat" to point.latitude
        )

        if (feature != null) {
            arguments["id"] = feature.id()
            methodChannel.invokeMethod("feature#onTap", arguments)
        } else {
            methodChannel.invokeMethod("map#onMapClick", arguments)
        }
        return true
    }

    override fun onMapLongClick(point: LatLng): Boolean {
        val pointf = mapboxMap!!.projection.toScreenLocation(point)
        val arguments = mapOf(
            "x" to pointf.x,
            "y" to pointf.y,
            "lng" to point.longitude,
            "lat" to point.latitude,
        )
        methodChannel.invokeMethod("map#onMapLongClick", arguments)
        return true
    }

    override fun dispose() {
        if (disposed) {
            return
        }
        disposed = true
        methodChannel.setMethodCallHandler(null)
        destroyMapViewIfNecessary()
        lifecycleProvider.lifecycle?.removeObserver(this)
    }

    private fun moveCamera(cameraUpdate: CameraUpdate?, result: MethodChannel.Result) {
        if (cameraUpdate != null) {
            // camera transformation not handled yet
            mapboxMap!!.moveCamera(
                cameraUpdate,
                object : OnCameraMoveFinishedListener() {
                    override fun onFinish() {
                        super.onFinish()
                        result.success(true)
                    }

                    override fun onCancel() {
                        super.onCancel()
                        result.success(false)
                    }
                })
        } else {
            result.success(false)
        }
    }

    private fun animateCamera(cameraUpdate: CameraUpdate?, result: MethodChannel.Result) {
        val onCameraMoveFinishedListener: OnCameraMoveFinishedListener =
            object : OnCameraMoveFinishedListener() {
                override fun onFinish() {
                    super.onFinish()
                    result.success(true)
                }

                override fun onCancel() {
                    super.onCancel()
                    result.success(false)
                }
            }
        if (cameraUpdate != null) {
            // camera transformation not handled yet
            mapboxMap!!.animateCamera(cameraUpdate, onCameraMoveFinishedListener)
        } else {
            result.success(false)
        }
    }

    /**
     * Destroy the MapView and cleans up listeners.
     * It's very important to call mapViewContainer.removeView(mapView) to make sure
     * that [TextureView.onDetachedFromWindow] is called which releases the
     * underlying surface.
     * This is required due to an FlutterEngine change that was introduce when updating from
     * Flutter 2.10.5 to Flutter 3.10.0.
     * This FlutterEngine change is not calling `removeView` on a PlatformView which causes the issue.
     *
     *
     * For more information check out:
     * [Flutter issue](https://github.com/flutter/flutter/issues/107297)
     * [Flutter Engine commit that introduced the issue](https://github.com/flutter/engine/commit/8dc7cd1b1a33b5da561ac859cdcc49705ad1e598)
     * [The reported issue in the MapLibre repo](https://github.com/maplibre/flutter-maplibre-gl/issues/182)
     */
    private fun destroyMapViewIfNecessary() {
        if (mapView == null) {
            return
        }
        mapViewContainer.removeView(mapView)
        mapView!!.onStop()
        mapView!!.onDestroy()
        if (locationComponent != null) {
            locationComponent!!.isLocationComponentEnabled = false
        }
        stopListeningForLocationUpdates()
        mapView = null
    }

    override fun onCreate(owner: LifecycleOwner) {
        if (disposed) {
            return
        }
        mapView!!.onCreate(null)
    }

    override fun onStart(owner: LifecycleOwner) {
        if (disposed) {
            return
        }
        mapView!!.onStart()
    }

    override fun onResume(owner: LifecycleOwner) {
        if (disposed) {
            return
        }
        mapView!!.onResume()
        if (myLocationEnabled) {
            startListeningForLocationUpdates()
        }
    }

    override fun onPause(owner: LifecycleOwner) {
        if (disposed) {
            return
        }
        mapView!!.onPause()
    }

    override fun onStop(owner: LifecycleOwner) {
        if (disposed) {
            return
        }
        mapView!!.onStop()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        owner.lifecycle.removeObserver(this)
        if (disposed) {
            return
        }
        destroyMapViewIfNecessary()
    }

    // MapboxMapOptionsSink methods
    override fun setCameraTargetBounds(bounds: LatLngBounds) {
        this.bounds = bounds
    }

    override fun setCompassEnabled(compassEnabled: Boolean) {
        mapboxMap!!.uiSettings.isCompassEnabled = compassEnabled
    }

    override fun setTrackCameraPosition(trackCameraPosition: Boolean) {
        this.trackCameraPosition = trackCameraPosition
    }

    override fun setRotateGesturesEnabled(rotateGesturesEnabled: Boolean) {
        mapboxMap!!.uiSettings.isRotateGesturesEnabled = rotateGesturesEnabled
    }

    override fun setScrollGesturesEnabled(scrollGesturesEnabled: Boolean) {
        mapboxMap!!.uiSettings.isScrollGesturesEnabled = scrollGesturesEnabled
    }

    override fun setTiltGesturesEnabled(tiltGesturesEnabled: Boolean) {
        mapboxMap!!.uiSettings.isTiltGesturesEnabled = tiltGesturesEnabled
    }

    override fun setMinMaxZoomPreference(min: Float?, max: Float?) {
        mapboxMap!!.setMinZoomPreference((min ?: MapboxConstants.MINIMUM_ZOOM).toDouble())
        mapboxMap!!.setMaxZoomPreference((max ?: MapboxConstants.MAXIMUM_ZOOM).toDouble())
    }

    override fun setZoomGesturesEnabled(zoomGesturesEnabled: Boolean) {
        mapboxMap!!.uiSettings.isZoomGesturesEnabled = zoomGesturesEnabled
    }

    override fun setMyLocationEnabled(myLocationEnabled: Boolean) {
        if (this.myLocationEnabled == myLocationEnabled) {
            return
        }
        this.myLocationEnabled = myLocationEnabled
        if (mapboxMap != null) {
            updateMyLocationEnabled()
        }
    }

    override fun setMyLocationTrackingMode(myLocationTrackingMode: Int) {
        if (mapboxMap != null) {
            // ensure that location is trackable
            updateMyLocationEnabled()
        }
        if (this.myLocationTrackingMode == myLocationTrackingMode) {
            return
        }
        this.myLocationTrackingMode = myLocationTrackingMode
        if (mapboxMap != null && locationComponent != null) {
            updateMyLocationTrackingMode()
        }
    }

    override fun setMyLocationRenderMode(myLocationRenderMode: Int) {
        if (this.myLocationRenderMode == myLocationRenderMode) {
            return
        }
        this.myLocationRenderMode = myLocationRenderMode
        if (mapboxMap != null && locationComponent != null) {
            updateMyLocationRenderMode()
        }
    }

    override fun setLogoViewMargins(x: Int, y: Int) {
        mapboxMap!!.uiSettings.setLogoMargins(x, 0, 0, y)
    }

    override fun setCompassGravity(gravity: Int) {
        when (gravity) {
            0 -> mapboxMap!!.uiSettings.compassGravity = Gravity.TOP or Gravity.START
            1 -> mapboxMap!!.uiSettings.compassGravity = Gravity.TOP or Gravity.END
            2 -> mapboxMap!!.uiSettings.compassGravity =
                Gravity.BOTTOM or Gravity.START

            3 -> mapboxMap!!.uiSettings.compassGravity = Gravity.BOTTOM or Gravity.END
            else -> mapboxMap!!.uiSettings.compassGravity = Gravity.TOP or Gravity.END
        }
    }

    override fun setCompassViewMargins(x: Int, y: Int) {
        when (mapboxMap!!.uiSettings.compassGravity) {
            Gravity.TOP or Gravity.START -> mapboxMap!!.uiSettings.setCompassMargins(x, y, 0, 0)
            Gravity.TOP or Gravity.END -> mapboxMap!!.uiSettings.setCompassMargins(0, y, x, 0)
            Gravity.BOTTOM or Gravity.START -> mapboxMap!!.uiSettings.setCompassMargins(x, 0, 0, y)
            Gravity.BOTTOM or Gravity.END -> mapboxMap!!.uiSettings.setCompassMargins(0, 0, x, y)
            else -> mapboxMap!!.uiSettings.setCompassMargins(0, y, x, 0)
        }
    }

    override fun setAttributionButtonGravity(gravity: Int) {
        when (gravity) {
            0 -> mapboxMap!!.uiSettings.attributionGravity =
                Gravity.TOP or Gravity.START

            1 -> mapboxMap!!.uiSettings.attributionGravity = Gravity.TOP or Gravity.END
            2 -> mapboxMap!!.uiSettings.attributionGravity = Gravity.BOTTOM or Gravity.START
            3 -> mapboxMap!!.uiSettings.attributionGravity = Gravity.BOTTOM or Gravity.END
            else -> mapboxMap!!.uiSettings.attributionGravity = Gravity.TOP or Gravity.END
        }
    }

    override fun setAttributionButtonMargins(x: Int, y: Int) {
        when (mapboxMap!!.uiSettings.attributionGravity) {
            Gravity.TOP or Gravity.START -> mapboxMap!!.uiSettings.setAttributionMargins(x, y, 0, 0)
            Gravity.TOP or Gravity.END -> mapboxMap!!.uiSettings.setAttributionMargins(0, y, x, 0)
            Gravity.BOTTOM or Gravity.START -> mapboxMap!!.uiSettings.setAttributionMargins(
                x,
                0,
                0,
                y
            )

            Gravity.BOTTOM or Gravity.END -> mapboxMap!!.uiSettings.setAttributionMargins(
                0,
                0,
                x,
                y
            )

            else -> mapboxMap!!.uiSettings.setAttributionMargins(0, y, x, 0)
        }
    }

    private fun updateMyLocationEnabled() {
        if (locationComponent == null && myLocationEnabled) {
            enableLocationComponent(mapboxMap!!.style!!)
        }
        if (myLocationEnabled) {
            startListeningForLocationUpdates()
        } else {
            stopListeningForLocationUpdates()
        }
        if (locationComponent != null) {
            locationComponent!!.isLocationComponentEnabled = myLocationEnabled
        }
    }

    private fun startListeningForLocationUpdates() {
        if (locationEngineCallback == null && locationComponent != null && locationComponent!!.locationEngine != null) {
            val locationEngineCallback = object : LocationEngineCallback<LocationEngineResult> {
                override fun onSuccess(result: LocationEngineResult) {
                    onUserLocationUpdate(result.lastLocation)
                }

                override fun onFailure(exception: Exception) {}
            }

            this.locationEngineCallback = locationEngineCallback

            locationComponent!!
                .locationEngine!!
                .requestLocationUpdates(
                    locationComponent!!.locationEngineRequest, locationEngineCallback, null
                )
        }
    }

    private fun stopListeningForLocationUpdates() {
        if (locationEngineCallback != null && locationComponent != null && locationComponent!!.locationEngine != null) {
            locationComponent!!.locationEngine!!
                .removeLocationUpdates(locationEngineCallback!!)
            locationEngineCallback = null
        }
    }

    private fun updateMyLocationTrackingMode() {
        val mapboxTrackingModes = intArrayOf(
            CameraMode.NONE,
            CameraMode.TRACKING,
            CameraMode.TRACKING_COMPASS,
            CameraMode.TRACKING_GPS
        )
        locationComponent!!.cameraMode = mapboxTrackingModes[myLocationTrackingMode]
    }

    private fun updateMyLocationRenderMode() {
        val mapboxRenderModes = intArrayOf(RenderMode.NORMAL, RenderMode.COMPASS, RenderMode.GPS)
        locationComponent!!.renderMode = mapboxRenderModes[myLocationRenderMode]
    }

    private fun hasLocationPermission(): Boolean {
        return (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED)
    }

    private fun checkSelfPermission(permission: String): Int {
        return context.checkPermission(permission, Process.myPid(), Process.myUid())
    }

    /**
     * Tries to find highest scale image for display type
     *
     * @param imageId
     * @param density
     * @return
     */
    private fun getScaledImage(imageId: String, density: Float): Bitmap? {
        var assetFileDescriptor: AssetFileDescriptor

        // Split image path into parts.
        val imagePathList =
            listOf(*imageId.split("/".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray())
        val assetPathList: MutableList<String> = ArrayList()

        // "On devices with a device pixel ratio of 1.8, the asset .../2.0x/my_icon.png would be chosen.
        // For a device pixel ratio of 2.7, the asset .../3.0x/my_icon.png would be chosen."
        // Source: https://flutter.dev/docs/development/ui/assets-and-images#resolution-aware
        for (i in ceil(density.toDouble()).toInt() downTo 1) {
            val assetPath: String = if (i == 1) {
                // If density is 1.0x then simply take the default asset path
                MapboxMapsPlugin.flutterAssets.getAssetFilePathByName(imageId)
            } else {
                // Build a resolution aware asset path as follows:
                // <directory asset>/<ratio>/<image name>
                // where ratio is 1.0x, 2.0x or 3.0x.
                val stringBuilder = StringBuilder()
                for (j in 0 until imagePathList.size - 1) {
                    stringBuilder.append(imagePathList[j])
                    stringBuilder.append("/")
                }
                stringBuilder.append(i.toFloat().toString() + "x")
                stringBuilder.append("/")
                stringBuilder.append(imagePathList[imagePathList.size - 1])
                MapboxMapsPlugin.flutterAssets.getAssetFilePathByName(stringBuilder.toString())
            }
            // Build up a list of resolution aware asset paths.
            assetPathList.add(assetPath)
        }

        // Iterate over asset paths and get the highest scaled asset (as a bitmap).
        var bitmap: Bitmap? = null
        for (assetPath in assetPathList) {
            try {
                // Read path (throws exception if doesn't exist).
                assetFileDescriptor = mapView!!.context.assets.openFd(assetPath)
                val assetStream: InputStream = assetFileDescriptor.createInputStream()
                bitmap = BitmapFactory.decodeStream(assetStream)
                assetFileDescriptor.close() // Close for memory
                break // If exists, break
            } catch (e: IOException) {
                // Skip
            }
        }
        return bitmap
    }

    fun onMoveBegin(detector: MoveGestureDetector): Boolean {
        // onMoveBegin gets called even during a move - move end is also not called unless this function
        // returns
        // true at least once. To avoid redundant queries only check for feature if the previous event
        // was ACTION_DOWN
        if (detector.previousEvent.actionMasked == MotionEvent.ACTION_DOWN
            && detector.pointersCount == 1
        ) {
            val pointf = detector.focalPoint
            val origin = mapboxMap!!.projection.fromScreenLocation(pointf)
            val rectF = RectF(pointf.x - 10, pointf.y - 10, pointf.x + 10, pointf.y + 10)
            val feature = firstFeatureOnLayers(rectF)
            if (feature != null && startDragging(feature, origin)) {
                invokeFeatureDrag(pointf, "start")
                return true
            }
        }
        return false
    }

    private fun invokeFeatureDrag(pointf: PointF, eventType: String) {
        val current = mapboxMap!!.projection.fromScreenLocation(pointf)
        val arguments = mapOf(
            "id" to draggedFeature!!.id(),
            "x" to pointf.x,
            "y" to pointf.y,
            "originLng" to dragOrigin!!.longitude,
            "originLat" to dragOrigin!!.latitude,
            "currentLng" to current.longitude,
            "currentLat" to current.latitude,
            "eventType" to eventType,
            "deltaLng" to current.longitude - dragPrevious!!.longitude,
            "deltaLat" to current.latitude - dragPrevious!!.latitude,
        )

        dragPrevious = current
        methodChannel.invokeMethod("feature#onDrag", arguments)
    }

    fun onMove(detector: MoveGestureDetector): Boolean {
        if (draggedFeature != null) {
            if (detector.pointersCount > 1) {
                stopDragging()
                return true
            }
            val pointf = detector.focalPoint
            invokeFeatureDrag(pointf, "drag")
            return false
        }
        return true
    }

    fun onMoveEnd(detector: MoveGestureDetector) {
        val pointf = detector.focalPoint
        invokeFeatureDrag(pointf, "end")
        stopDragging()
    }

    private fun startDragging(feature: Feature, origin: LatLng): Boolean {
        val draggable =
            if (feature.hasNonNullValueForProperty("draggable")) feature.getBooleanProperty("draggable") else false
        if (draggable) {
            draggedFeature = feature
            dragPrevious = origin
            dragOrigin = origin
            return true
        }
        return false
    }

    private fun stopDragging() {
        draggedFeature = null
        dragOrigin = null
        dragPrevious = null
    }

    /** Simple Listener to listen for the status of camera movements.  */
    open inner class OnCameraMoveFinishedListener : CancelableCallback {
        override fun onFinish() {}
        override fun onCancel() {}
    }

    private inner class MoveGestureListener : OnMoveGestureListener {
        override fun onMoveBegin(detector: MoveGestureDetector): Boolean {
            return this@MapboxMapController.onMoveBegin(detector)
        }

        override fun onMove(
            detector: MoveGestureDetector,
            distanceX: Float,
            distanceY: Float
        ): Boolean {
            return this@MapboxMapController.onMove(detector)
        }

        override fun onMoveEnd(detector: MoveGestureDetector, velocityX: Float, velocityY: Float) {
            this@MapboxMapController.onMoveEnd(detector)
        }
    }

    companion object {
        private const val TAG = "MapboxMapController"
    }
}