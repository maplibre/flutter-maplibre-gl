package org.maplibre.maplibregl

import android.content.Context
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import org.maplibre.android.location.engine.LocationEngine
import org.maplibre.android.location.engine.LocationEngineProxy

/**
 * The only place that touches Google Play Services.
 *
 * It is in the `gms` source set, compiled with play-services-location unless the app sets
 * `maplibre_gl.playServicesLocation=false` (#1014), and [FusedLocationEngineProvider] finds it by
 * name. An app can still resolve a version older than 21.0.0, for example when it forces one; the
 * API the engine uses is checked here, so a mismatch falls back to the platform engine instead of
 * failing on the first location request.
 */
internal class GmsLocationSupport : FusedLocationEngineProvider {
    @Volatile
    private var unusable = false

    override fun createFusedLocationEngine(context: Context): LocationEngine? {
        if (unusable) {
            return null
        }
        return try {
            val availability = GoogleApiAvailability.getInstance()
            if (availability.isGooglePlayServicesAvailable(context) != ConnectionResult.SUCCESS) {
                // Play Services missing or outdated on the device (for example a Huawei device
                // with HMS only).
                null
            } else {
                val engine = GMSLocationEngine(context)
                if (isApiCompatible()) LocationEngineProxy(engine) else null
            }
        } catch (e: LinkageError) {
            onIncompatibleVersion(e)
            null
        } catch (e: Exception) {
            Log.w(TAG, "Google Play Services location unavailable, using the platform engine", e)
            null
        }
    }

    /**
     * Any [LinkageError] here, a missing class included (LocationRequest.Builder does not exist
     * before 21.0.0), means a version that is too old.
     */
    private fun isApiCompatible(): Boolean {
        return try {
            GMSLocationEngine.checkApiCompatible()
            true
        } catch (e: LinkageError) {
            onIncompatibleVersion(e)
            false
        }
    }

    private fun onIncompatibleVersion(e: LinkageError) {
        unusable = true
        Log.w(
            TAG,
            "incompatible play-services-location version, the plugin needs 21.0.0 or later; " +
                "using the platform engine",
            e
        )
    }

    private companion object {
        const val TAG = "MapLibreGmsLocation"
    }
}
