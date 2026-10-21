package org.maplibre.maplibregl

import com.google.gson.JsonParser
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdate
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.geometry.LatLngQuad
import org.maplibre.android.location.engine.LocationEngineRequest
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.style.expressions.Expression

/**
 * Conversions of the typed map messages into MapLibre types, and of the map options into calls of
 * a [MapLibreMapOptionsSink]. Screen values arrive in logical pixels and become physical pixels at
 * `density` pixels per logical pixel.
 */
internal object PigeonConvert {
    @JvmStatic
    fun toLatLng(latLng: PgLatLng) = LatLng(latLng.latitude, latLng.longitude)

    @JvmStatic
    fun toLatLngBounds(bounds: PgLatLngBounds): LatLngBounds =
        LatLngBounds.Builder()
            .include(toLatLng(bounds.southwest))
            .include(toLatLng(bounds.northeast))
            .build()

    @JvmStatic
    fun toLatLngQuad(quad: PgLatLngQuad) =
        LatLngQuad(
            toLatLng(quad.topLeft),
            toLatLng(quad.topRight),
            toLatLng(quad.bottomRight),
            toLatLng(quad.bottomLeft),
        )

    @JvmStatic
    fun toCameraPosition(position: PgCameraPosition): CameraPosition =
        CameraPosition.Builder()
            .bearing(position.bearing)
            .target(toLatLng(position.target))
            .tilt(position.tilt)
            .zoom(position.zoom)
            .build()

    /**
     * [update] as a [CameraUpdate], read against the camera [map] has now. Only scrollBy, zoomBy
     * with a focus and newLatLngBounds read [map].
     */
    @JvmStatic
    fun toCameraUpdate(update: PgCameraUpdate, map: MapLibreMap?, density: Float): CameraUpdate =
        when (update) {
            is PgCameraUpdateNewCameraPosition ->
                CameraUpdateFactory.newCameraPosition(toCameraPosition(update.cameraPosition))
            is PgCameraUpdateNewLatLng -> CameraUpdateFactory.newLatLng(toLatLng(update.latLng))
            is PgCameraUpdateNewLatLngBounds -> {
                val padding = update.padding
                Convert.toBoundsCameraUpdate(
                    map,
                    toLatLngBounds(update.bounds),
                    padding.left,
                    padding.top,
                    padding.right,
                    padding.bottom,
                    density,
                )
            }
            is PgCameraUpdateNewLatLngZoom ->
                CameraUpdateFactory.newLatLngZoom(toLatLng(update.latLng), update.zoom)
            is PgCameraUpdateScrollBy -> Convert.scrollBy(map, update.dx, update.dy, density)
            is PgCameraUpdateZoomBy -> {
                val focus = update.focus
                if (focus == null) {
                    CameraUpdateFactory.zoomBy(update.amount)
                } else {
                    Convert.zoomBy(map, update.amount, focus.x, focus.y, density)
                }
            }
            is PgCameraUpdateZoomIn -> CameraUpdateFactory.zoomIn()
            is PgCameraUpdateZoomOut -> CameraUpdateFactory.zoomOut()
            is PgCameraUpdateZoomTo -> CameraUpdateFactory.zoomTo(update.zoom)
            is PgCameraUpdateBearingTo -> CameraUpdateFactory.bearingTo(update.bearing)
            is PgCameraUpdateTiltTo -> CameraUpdateFactory.tiltTo(update.tilt)
        }

    /**
     * Hands [sink] the options that are set in [options], and nothing for the null ones: at
     * creation the sink keeps its defaults, and on an update the option stays as it is. Margins
     * are converted to physical pixels.
     */
    @JvmStatic
    fun applyMapOptions(options: PgMapOptions, sink: MapLibreMapOptionsSink, density: Float) {
        fun pixels(value: Double) = Convert.toPixels(value, density)

        // The order is the one the options have always been applied in: the location source
        // before the location component is enabled, and each ornament position before its
        // margins, which are laid out for the corner the ornament is in.
        options.locationEngineProperties?.let { properties ->
            toLocationEngineRequest(properties)?.let { sink.setLocationEngineProperties(it) }
        }
        options.locationSource?.let {
            sink.setLocationSource(
                when (it) {
                    PgLocationSource.PLATFORM -> "platform"
                    PgLocationSource.MANUAL -> "manual"
                },
            )
        }
        options.cameraTargetBounds?.let {
            sink.setCameraTargetBounds(it.bounds?.let(::toLatLngBounds))
        }
        options.compassEnabled?.let { sink.setCompassEnabled(it) }
        options.styleString?.let { sink.setStyleString(it) }
        options.minMaxZoomPreference?.let {
            sink.setMinMaxZoomPreference(it.minZoom?.toFloat(), it.maxZoom?.toFloat())
        }
        options.rotateGesturesEnabled?.let { sink.setRotateGesturesEnabled(it) }
        options.scrollGesturesEnabled?.let { sink.setScrollGesturesEnabled(it) }
        options.tiltGesturesEnabled?.let { sink.setTiltGesturesEnabled(it) }
        options.panInertia?.let { sink.setPanInertia(it.raw) }
        options.trackCameraPosition?.let { sink.setTrackCameraPosition(it) }
        options.zoomGesturesEnabled?.let { sink.setZoomGesturesEnabled(it) }
        options.doubleClickZoomEnabled?.let { sink.setDoubleClickZoomEnabled(it) }
        options.myLocationEnabled?.let { sink.setMyLocationEnabled(it) }
        options.myLocationTrackingMode?.let { sink.setMyLocationTrackingMode(it.raw) }
        options.myLocationRenderMode?.let { sink.setMyLocationRenderMode(it.raw) }
        options.myLocationStyle?.let { sink.setMyLocationStyle(LocationPuckStyle.from(it)) }
        options.logoEnabled?.let { sink.setLogoEnabled(it) }
        options.logoViewPosition?.let { sink.setLogoViewGravity(it.raw) }
        options.logoViewMargins?.let { sink.setLogoViewMargins(pixels(it.x), pixels(it.y)) }
        options.compassViewPosition?.let { sink.setCompassGravity(it.raw) }
        options.compassViewMargins?.let { sink.setCompassViewMargins(pixels(it.x), pixels(it.y)) }
        options.attributionEnabled?.let { sink.setAttributionEnabled(it) }
        options.attributionButtonPosition?.let { sink.setAttributionButtonGravity(it.raw) }
        options.attributionButtonMargins?.let {
            sink.setAttributionButtonMargins(pixels(it.x), pixels(it.y))
        }
        // ARGB colors above Int.MAX_VALUE keep their bits as a negative Int.
        options.attributionButtonColor?.let { sink.setAttributionButtonColor(it.toInt()) }
        options.foregroundLoadColor?.let { sink.setForegroundLoadColor(it.toInt()) }
        options.translucentTextureSurface?.let { sink.setTranslucentTextureSurface(it) }
        options.featureTapsTriggersMapClick?.let { sink.setFeatureTapsTriggersMapClick(it) }
        options.symbolPlacementTransitionsEnabled?.let {
            sink.setSymbolPlacementTransitionsEnabled(it)
        }
    }

    /**
     * The location request of [properties], or null without the interval it is built on. On
     * Android Dart sends the interval, the priority and the displacement together.
     */
    @JvmStatic
    fun toLocationEngineRequest(properties: PgLocationEngineProperties): LocationEngineRequest? {
        val interval = properties.interval ?: return null
        val builder = LocationEngineRequest.Builder(interval)
        properties.priority?.let { builder.setPriority(it.raw) }
        properties.displacement?.let { builder.setDisplacement(it.toFloat()) }
        return builder.build()
    }

    /**
     * The filter of a feature query, the JSON text of an expression, or null when there is none.
     * Only an expression array filters: null, the text `null` and any other value do not.
     */
    @JvmStatic
    fun toQueryFilter(filter: String?): Expression? {
        if (filter == null) {
            return null
        }
        val json = JsonParser.parseString(filter)
        return if (json.isJsonArray) Expression.Converter.convert(json.asJsonArray) else null
    }
}
