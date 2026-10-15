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
 * The plugin compiles against play-services-location but does not ship it (#1014): an app gets
 * the fused provider only if it adds the dependency itself. When the classes are missing, the
 * first reference to them throws [NoClassDefFoundError], which is a [LinkageError] and not an
 * [Exception], so it is caught here explicitly. Plain references keep this safe under R8: no
 * class names in strings, nothing renamed out from under a lookup.
 */
internal object GmsLocationSupport {
    private const val TAG = "MapLibreGmsLocation"

    @Volatile
    private var classesMissing = false

    /**
     * Returns an engine on the fused location provider, or null when the app does not include
     * play-services-location or the device has no usable Google Play Services.
     */
    fun createFusedLocationEngine(context: Context): LocationEngine? {
        if (classesMissing) {
            return null
        }
        return try {
            val availability = GoogleApiAvailability.getInstance()
            if (availability.isGooglePlayServicesAvailable(context) != ConnectionResult.SUCCESS) {
                // Classes present, but Play Services missing or outdated on the device
                // (for example a Huawei device with HMS only).
                null
            } else {
                LocationEngineProxy(GMSLocationEngine(context))
            }
        } catch (e: LinkageError) {
            // The app does not include play-services-location (or only part of it).
            classesMissing = true
            Log.i(
                TAG,
                "play-services-location is not in the app, using the platform location engine. " +
                    "Add com.google.android.gms:play-services-location to use the fused provider."
            )
            null
        } catch (e: Exception) {
            Log.w(TAG, "Google Play Services location unavailable, using the platform engine", e)
            null
        }
    }
}
