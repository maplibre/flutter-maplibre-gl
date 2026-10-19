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
 * [Exception], so it is caught here explicitly. An app can also get a version older than 21.0.0
 * from another plugin; the API the engine uses is checked here too, so a mismatch falls back to
 * the platform engine instead of failing on the first location request. Plain references keep
 * this safe under R8: no class names in strings, nothing renamed out from under a lookup.
 */
internal object GmsLocationSupport {
    private const val TAG = "MapLibreGmsLocation"

    @Volatile
    private var classesMissing = false

    @Volatile
    private var versionIncompatible = false

    /**
     * Returns an engine on the fused location provider, or null when the app does not include
     * play-services-location, includes a version older than 21.0.0, or the device has no usable
     * Google Play Services.
     */
    fun createFusedLocationEngine(context: Context): LocationEngine? {
        if (classesMissing || versionIncompatible) {
            return null
        }
        return try {
            val availability = GoogleApiAvailability.getInstance()
            if (availability.isGooglePlayServicesAvailable(context) != ConnectionResult.SUCCESS) {
                // Classes present, but Play Services missing or outdated on the device
                // (for example a Huawei device with HMS only).
                null
            } else {
                // Throws NoClassDefFoundError when play-services-location is not in the app.
                val engine = GMSLocationEngine(context)
                if (isApiCompatible()) LocationEngineProxy(engine) else null
            }
        } catch (e: NoClassDefFoundError) {
            // The app does not include play-services-location (or only part of it).
            classesMissing = true
            Log.i(
                TAG,
                "play-services-location is not in the app, using the platform location engine. " +
                    "Add com.google.android.gms:play-services-location to use the fused provider."
            )
            null
        } catch (e: LinkageError) {
            onIncompatibleVersion(e)
            null
        } catch (e: Exception) {
            Log.w(TAG, "Google Play Services location unavailable, using the platform engine", e)
            null
        }
    }

    /**
     * The location classes are in the app, so any [LinkageError] here, a missing class included
     * (LocationRequest.Builder does not exist before 21.0.0), means a version that is too old.
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
        versionIncompatible = true
        Log.w(
            TAG,
            "incompatible play-services-location version, the plugin needs 21.0.0 or later; " +
                "using the platform engine",
            e
        )
    }
}
