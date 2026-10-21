package org.maplibre.maplibregl

import io.flutter.plugin.common.StandardMessageCodec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.maplibre.android.camera.CameraPosition

/**
 * Dart hands each map view a PgCreationParams, encoded with the codec of the map messages. The
 * factory decodes it with the same codec and configures the builder of the map from it.
 */
class MapLibreMapFactoryTest {
    /** Records what the factory hands it, on top of what the builder does with it. */
    private class RecordingBuilder : MapLibreMapBuilder() {
        val calls = mutableListOf<String>()

        override fun setInitialCameraPosition(position: CameraPosition) {
            calls.add("initialCameraPosition ${position.target} ${position.zoom}")
            super.setInitialCameraPosition(position)
        }

        override fun setDragEnabled(enabled: Boolean) {
            calls.add("dragEnabled $enabled")
            super.setDragEnabled(enabled)
        }

        override fun setStyleString(styleString: String) {
            calls.add("styleString $styleString")
            super.setStyleString(styleString)
        }

        override fun setUseHybridComposition(useHybridComposition: Boolean) {
            calls.add("useHybridComposition $useHybridComposition")
            super.setUseHybridComposition(useHybridComposition)
        }

        override fun setCompassEnabled(compassEnabled: Boolean) {
            calls.add("compassEnabled $compassEnabled")
            super.setCompassEnabled(compassEnabled)
        }

        override fun setLogoViewMargins(x: Int, y: Int) {
            calls.add("logoViewMargins $x $y")
            super.setLogoViewMargins(x, y)
        }
    }

    /** [message] as the factory receives it: encoded and decoded by the codec of the messages. */
    private fun throughTheCodec(message: Any): Any? {
        val buffer = MapLibreMapHostApi.codec.encodeMessage(message)!!
        buffer.flip()
        return MapLibreMapHostApi.codec.decodeMessage(buffer)
    }

    private fun configure(args: Any?, density: Float = 2f): List<String> {
        val builder = RecordingBuilder()
        MapLibreMapFactory.configure(builder, args, density)
        return builder.calls
    }

    @Test
    fun theCreationParamsCrossTheCodecWhole() {
        val params = PgCreationParams(
            styleString = "assets/style.json",
            options = PgMapOptions(
                compassEnabled = false,
                logoViewMargins = PgScreenPoint(4.5, 8.0),
                myLocationTrackingMode = PgMyLocationTrackingMode.TRACKING_GPS,
                cameraTargetBounds = PgCameraTargetBounds(),
            ),
            initialCameraPosition = PgCameraPosition(0.0, PgLatLng(45.0, 9.0), 0.0, 11.5),
            dragEnabled = false,
            iosLongClickDurationMs = 500L,
            useHybridComposition = true,
        )

        assertEquals(params, throughTheCodec(params))
    }

    @Test
    fun theFactoryAppliesEveryCreationParam() {
        val params = PgCreationParams(
            styleString = "assets/style.json",
            options = PgMapOptions(
                compassEnabled = false,
                styleString = "assets/style.json",
                logoViewMargins = PgScreenPoint(4.5, 8.0),
            ),
            initialCameraPosition = PgCameraPosition(0.0, PgLatLng(45.0, 9.0), 0.0, 11.5),
            dragEnabled = false,
            useHybridComposition = true,
        )

        assertEquals(
            listOf(
                "compassEnabled false",
                "styleString assets/style.json",
                "logoViewMargins 9 16",
                "initialCameraPosition ${PigeonConvert.toLatLng(PgLatLng(45.0, 9.0))} 11.5",
                "dragEnabled false",
                "styleString assets/style.json",
                "useHybridComposition true",
            ),
            configure(throughTheCodec(params), density = 2f),
        )
    }

    @Test
    fun theCompositionIsSetEvenWithoutHybridComposition() {
        val params = PgCreationParams(
            options = PgMapOptions(),
            dragEnabled = true,
            useHybridComposition = false,
        )

        // No style and no camera: the builder keeps its defaults for them.
        assertEquals(
            listOf("dragEnabled true", "useHybridComposition false"),
            configure(throughTheCodec(params)),
        )
    }

    @Test
    fun theFactoryRejectsCreationParamsOfAnotherShape() {
        // Creation params as a plain map rather than a PgCreationParams.
        val legacy = mapOf("options" to mapOf("compassEnabled" to true), "dragEnabled" to true)
        val buffer = StandardMessageCodec.INSTANCE.encodeMessage(legacy)!!
        buffer.flip()
        val decoded = MapLibreMapHostApi.codec.decodeMessage(buffer)

        val error = assertThrows(IllegalArgumentException::class.java) { configure(decoded) }
        assertEquals(
            "The creation params of a map are a PgCreationParams, not $decoded.",
            error.message,
        )
        assertThrows(IllegalArgumentException::class.java) { configure(null) }
    }
}
