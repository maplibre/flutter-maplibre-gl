package org.maplibre.maplibregl

import android.content.Context
import android.util.Log
import org.maplibre.android.location.engine.LocationEngine

/**
 * Creates engines on Google's fused location provider.
 *
 * The only implementation, [GmsLocationSupport], lives in the `gms` source set, which the build
 * compiles together with play-services-location unless the app sets
 * `maplibre_gl.playServicesLocation=false` (#1014). Without it nothing in the plugin refers to
 * Google Play Services, so the main source set looks the implementation up by name.
 */
internal interface FusedLocationEngineProvider {
    /** Returns an engine on the fused provider, or null when it cannot be used on this device. */
    fun createFusedLocationEngine(context: Context): LocationEngine?

    companion object {
        private const val TAG = "MapLibreLocation"

        // Kept by consumer-rules.pro, so the name survives R8.
        private const val IMPLEMENTATION = "org.maplibre.maplibregl.GmsLocationSupport"

        /** The fused provider support compiled into this build, or null when it was left out. */
        val instance: FusedLocationEngineProvider? by lazy {
            try {
                Class.forName(IMPLEMENTATION).getDeclaredConstructor().newInstance()
                    as FusedLocationEngineProvider
            } catch (e: ClassNotFoundException) {
                Log.i(
                    TAG,
                    "built with maplibre_gl.playServicesLocation=false, using the platform " +
                        "location engine"
                )
                null
            } catch (e: ReflectiveOperationException) {
                Log.w(TAG, "fused location support unavailable, using the platform engine", e)
                null
            }
        }
    }
}
