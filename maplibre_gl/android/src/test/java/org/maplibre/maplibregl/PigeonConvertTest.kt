package org.maplibre.maplibregl

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.location.engine.LocationEngineRequest

/** How the typed map messages become MapLibre values and calls of the options sink. */
class PigeonConvertTest {
    private val target = PgLatLng(45.0, 9.0)

    private fun cameraUpdate(update: PgCameraUpdate) = PigeonConvert.toCameraUpdate(update, null, 2f)

    private fun position(update: PgCameraUpdate) =
        cameraUpdate(update) as CameraUpdateFactory.CameraPositionUpdate

    private fun zoom(update: PgCameraUpdate) = cameraUpdate(update) as CameraUpdateFactory.ZoomUpdate

    @Test
    fun aNewCameraPositionKeepsEveryValue() {
        val update = position(
            PgCameraUpdateNewCameraPosition(PgCameraPosition(90.0, target, 30.0, 12.5)),
        )

        assertEquals(90.0, update.bearing, 0.0)
        assertEquals(LatLng(45.0, 9.0), update.target)
        assertEquals(30.0, update.tilt, 0.0)
        assertEquals(12.5, update.zoom, 0.0)
    }

    @Test
    fun theUpdatesThatNeedNoMapBecomeTheirSdkUpdate() {
        assertEquals(LatLng(45.0, 9.0), position(PgCameraUpdateNewLatLng(target)).target)

        val latLngZoom = position(PgCameraUpdateNewLatLngZoom(target, 10.0))
        assertEquals(LatLng(45.0, 9.0), latLngZoom.target)
        assertEquals(10.0, latLngZoom.zoom, 0.0)

        val zoomBy = zoom(PgCameraUpdateZoomBy(-2.0))
        assertEquals(CameraUpdateFactory.ZoomUpdate.ZOOM_BY, zoomBy.type)
        assertEquals(-2.0, zoomBy.zoom, 0.0)

        assertEquals(CameraUpdateFactory.ZoomUpdate.ZOOM_IN, zoom(PgCameraUpdateZoomIn()).type)
        assertEquals(CameraUpdateFactory.ZoomUpdate.ZOOM_OUT, zoom(PgCameraUpdateZoomOut()).type)

        val zoomTo = zoom(PgCameraUpdateZoomTo(12.0))
        assertEquals(CameraUpdateFactory.ZoomUpdate.ZOOM_TO, zoomTo.type)
        assertEquals(12.0, zoomTo.zoom, 0.0)

        assertEquals(45.0, position(PgCameraUpdateBearingTo(45.0)).bearing, 0.0)
        assertEquals(60.0, position(PgCameraUpdateTiltTo(60.0)).tilt, 0.0)
    }

    @Test
    fun theCameraValuesKeepTheirDoublePrecision() {
        assertEquals(12.3, zoom(PgCameraUpdateZoomTo(12.3)).zoom, 0.0)
        assertEquals(
            LatLng(45.123456789, 9.987654321),
            position(PgCameraUpdateNewLatLng(PgLatLng(45.123456789, 9.987654321))).target,
        )
    }

    @Test
    fun boundsTakeTheirCornersInEitherOrder() {
        val bounds = PigeonConvert.toLatLngBounds(PgLatLngBounds(PgLatLng(46.0, 10.0), PgLatLng(44.0, 8.0)))

        assertEquals(44.0, bounds.getLatSouth(), 0.0)
        assertEquals(8.0, bounds.getLonWest(), 0.0)
        assertEquals(46.0, bounds.getLatNorth(), 0.0)
        assertEquals(10.0, bounds.getLonEast(), 0.0)
    }

    @Test
    fun aQuadKeepsTheOrderOfItsCorners() {
        val quad = PigeonConvert.toLatLngQuad(
            PgLatLngQuad(PgLatLng(1.0, 2.0), PgLatLng(3.0, 4.0), PgLatLng(5.0, 6.0), PgLatLng(7.0, 8.0)),
        )

        assertEquals(LatLng(1.0, 2.0), quad.topLeft)
        assertEquals(LatLng(3.0, 4.0), quad.topRight)
        assertEquals(LatLng(5.0, 6.0), quad.bottomRight)
        assertEquals(LatLng(7.0, 8.0), quad.bottomLeft)
    }

    @Test
    fun theLocationRequestTakesTheAndroidProperties() {
        val request = PigeonConvert.toLocationEngineRequest(
            PgLocationEngineProperties(
                interval = 5_000L,
                priority = PgLocationPriority.LOW_POWER,
                displacement = 10L,
            ),
        )!!

        assertEquals(5_000L, request.interval)
        assertEquals(LocationEngineRequest.PRIORITY_LOW_POWER, request.priority)
        assertEquals(10f, request.displacement)
    }

    @Test
    fun theLocationPrioritiesAreThoseOfTheSdk() {
        assertEquals(
            listOf(
                LocationEngineRequest.PRIORITY_HIGH_ACCURACY,
                LocationEngineRequest.PRIORITY_BALANCED_POWER_ACCURACY,
                LocationEngineRequest.PRIORITY_LOW_POWER,
                LocationEngineRequest.PRIORITY_NO_POWER,
            ),
            PgLocationPriority.entries.map { it.raw },
        )
    }

    @Test
    fun noLocationRequestWithoutAnInterval() {
        assertNull(PigeonConvert.toLocationEngineRequest(PgLocationEngineProperties(displacement = 10L)))
    }

    @Test
    fun optionsLeftOutCallNothing() {
        val sink = RecordingSink()

        PigeonConvert.applyMapOptions(PgMapOptions(hapticFeedbackEnabled = true), sink, 2f)

        assertEquals(emptyList<String>(), sink.calls)
    }

    @Test
    fun everyOptionThatIsSetReachesTheSinkInOrder() {
        val sink = RecordingSink()
        val options = PgMapOptions(
            compassEnabled = false,
            cameraTargetBounds = PgCameraTargetBounds(PgLatLngBounds(PgLatLng(44.0, 8.0), PgLatLng(46.0, 10.0))),
            styleString = "https://example.com/style.json",
            minMaxZoomPreference = PgMinMaxZoomPreference(2.0, 18.5),
            rotateGesturesEnabled = false,
            scrollGesturesEnabled = true,
            tiltGesturesEnabled = false,
            zoomGesturesEnabled = true,
            doubleClickZoomEnabled = false,
            panInertia = PgPanInertia.SHORT,
            hapticFeedbackEnabled = true,
            trackCameraPosition = true,
            myLocationEnabled = true,
            myLocationTrackingMode = PgMyLocationTrackingMode.TRACKING_COMPASS,
            myLocationRenderMode = PgMyLocationRenderMode.GPS,
            myLocationStyle = PgMyLocationStyle(fillColor = 0xFF336699L, accuracyCircleEnabled = false),
            logoEnabled = true,
            logoViewPosition = PgOrnamentPosition.BOTTOM_RIGHT,
            logoViewMargins = PgScreenPoint(4.5, 8.0),
            compassViewPosition = PgOrnamentPosition.TOP_LEFT,
            compassViewMargins = PgScreenPoint(1.3, 2.7),
            attributionEnabled = false,
            attributionButtonPosition = PgOrnamentPosition.TOP_RIGHT,
            attributionButtonMargins = PgScreenPoint(0.0, 10.0),
            attributionButtonColor = 0xFF336699L,
            locationEngineProperties = PgLocationEngineProperties(
                interval = 1_000L,
                priority = PgLocationPriority.BALANCED,
                displacement = 5L,
            ),
            locationSource = PgLocationSource.MANUAL,
            foregroundLoadColor = 0x80FFFFFFL,
            translucentTextureSurface = true,
            featureTapsTriggersMapClick = true,
            symbolPlacementTransitionsEnabled = false,
        )

        PigeonConvert.applyMapOptions(options, sink, 2f)

        assertEquals(
            listOf(
                "locationEngineProperties 1000 1 5.0",
                "locationSource manual",
                "cameraTargetBounds 44.0 8.0 46.0 10.0",
                "compassEnabled false",
                "styleString https://example.com/style.json",
                "minMaxZoomPreference 2.0 18.5",
                "rotateGesturesEnabled false",
                "scrollGesturesEnabled true",
                "tiltGesturesEnabled false",
                "panInertia 1",
                "trackCameraPosition true",
                "zoomGesturesEnabled true",
                "doubleClickZoomEnabled false",
                "myLocationEnabled true",
                "myLocationTrackingMode 2",
                "myLocationRenderMode 2",
                "myLocationStyle",
                "logoEnabled true",
                "logoViewGravity 3",
                "logoViewMargins 9 16",
                "compassGravity 0",
                // Rounded towards zero, in physical pixels.
                "compassViewMargins 2 5",
                "attributionEnabled false",
                "attributionButtonGravity 1",
                "attributionButtonMargins 0 20",
                "attributionButtonColor ${0xFF336699L.toInt()}",
                "foregroundLoadColor ${0x80FFFFFFL.toInt()}",
                "translucentTextureSurface true",
                "featureTapsTriggersMapClick true",
                "symbolPlacementTransitionsEnabled false",
            ),
            sink.calls,
        )
    }

    @Test
    fun targetBoundsWithoutBoundsLiftTheRestriction() {
        val sink = RecordingSink()

        PigeonConvert.applyMapOptions(PgMapOptions(cameraTargetBounds = PgCameraTargetBounds()), sink, 2f)

        assertEquals(listOf("cameraTargetBounds null"), sink.calls)
    }

    @Test
    fun aZoomPreferenceWithoutAnEndLeavesThatSideOpen() {
        val sink = RecordingSink()

        PigeonConvert.applyMapOptions(
            PgMapOptions(minMaxZoomPreference = PgMinMaxZoomPreference(maxZoom = 16.0)),
            sink,
            2f,
        )

        assertEquals(listOf("minMaxZoomPreference null 16.0"), sink.calls)
    }

    @Test
    fun thePlatformLocationSourceIsNotManual() {
        val sink = RecordingSink()

        PigeonConvert.applyMapOptions(PgMapOptions(locationSource = PgLocationSource.PLATFORM), sink, 2f)

        assertEquals(listOf("locationSource platform"), sink.calls)
    }

    /** Records each call it gets, with its arguments. */
    private class RecordingSink : MapLibreMapOptionsSink {
        val calls = mutableListOf<String>()

        private fun record(vararg values: Any?) {
            calls.add(values.joinToString(" "))
        }

        override fun setCameraTargetBounds(bounds: LatLngBounds?) = record(
            "cameraTargetBounds",
            bounds?.let { "${it.getLatSouth()} ${it.getLonWest()} ${it.getLatNorth()} ${it.getLonEast()}" },
        )
        override fun setCompassEnabled(compassEnabled: Boolean) = record("compassEnabled", compassEnabled)
        override fun setStyleString(styleString: String) = record("styleString", styleString)
        override fun setMinMaxZoomPreference(min: Float?, max: Float?) = record("minMaxZoomPreference", min, max)
        override fun setRotateGesturesEnabled(rotateGesturesEnabled: Boolean) =
            record("rotateGesturesEnabled", rotateGesturesEnabled)
        override fun setScrollGesturesEnabled(scrollGesturesEnabled: Boolean) =
            record("scrollGesturesEnabled", scrollGesturesEnabled)
        override fun setTiltGesturesEnabled(tiltGesturesEnabled: Boolean) =
            record("tiltGesturesEnabled", tiltGesturesEnabled)
        override fun setTrackCameraPosition(trackCameraPosition: Boolean) =
            record("trackCameraPosition", trackCameraPosition)
        override fun setZoomGesturesEnabled(zoomGesturesEnabled: Boolean) =
            record("zoomGesturesEnabled", zoomGesturesEnabled)
        override fun setDoubleClickZoomEnabled(doubleClickZoomEnabled: Boolean) =
            record("doubleClickZoomEnabled", doubleClickZoomEnabled)
        override fun setPanInertia(panInertia: Int) = record("panInertia", panInertia)
        override fun setMyLocationEnabled(myLocationEnabled: Boolean) = record("myLocationEnabled", myLocationEnabled)
        override fun setMyLocationTrackingMode(myLocationTrackingMode: Int) =
            record("myLocationTrackingMode", myLocationTrackingMode)
        override fun setMyLocationRenderMode(myLocationRenderMode: Int) =
            record("myLocationRenderMode", myLocationRenderMode)
        override fun setMyLocationStyle(style: LocationPuckStyle) = record("myLocationStyle")
        override fun setLogoEnabled(logoEnabled: Boolean) = record("logoEnabled", logoEnabled)
        override fun setLogoViewGravity(gravity: Int) = record("logoViewGravity", gravity)
        override fun setLogoViewMargins(x: Int, y: Int) = record("logoViewMargins", x, y)
        override fun setCompassGravity(gravity: Int) = record("compassGravity", gravity)
        override fun setCompassViewMargins(x: Int, y: Int) = record("compassViewMargins", x, y)
        override fun setAttributionEnabled(attributionEnabled: Boolean) = record("attributionEnabled", attributionEnabled)
        override fun setAttributionButtonGravity(gravity: Int) = record("attributionButtonGravity", gravity)
        override fun setAttributionButtonMargins(x: Int, y: Int) = record("attributionButtonMargins", x, y)
        override fun setAttributionButtonColor(color: Int) = record("attributionButtonColor", color)
        override fun setLocationEngineProperties(locationEngineRequest: LocationEngineRequest) =
            record(
                "locationEngineProperties",
                locationEngineRequest.interval,
                locationEngineRequest.priority,
                locationEngineRequest.displacement,
            )
        override fun setLocationSource(token: String) = record("locationSource", token)
        override fun setForegroundLoadColor(loadColor: Int) = record("foregroundLoadColor", loadColor)
        override fun setTranslucentTextureSurface(translucentTextureSurface: Boolean) =
            record("translucentTextureSurface", translucentTextureSurface)
        override fun setFeatureTapsTriggersMapClick(triggers: Boolean) = record("featureTapsTriggersMapClick", triggers)
        override fun setSymbolPlacementTransitionsEnabled(enabled: Boolean) =
            record("symbolPlacementTransitionsEnabled", enabled)
        override fun setUseHybridComposition(useHybridComposition: Boolean) =
            record("useHybridComposition", useHybridComposition)
    }
}
