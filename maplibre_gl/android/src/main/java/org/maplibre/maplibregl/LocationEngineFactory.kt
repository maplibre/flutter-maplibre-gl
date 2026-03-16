package org.maplibre.maplibregl

import android.content.Context
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import org.maplibre.android.location.LocationComponent
import org.maplibre.android.location.engine.LocationEngine
import org.maplibre.android.location.engine.LocationEngineDefault.getDefaultLocationEngine
import org.maplibre.android.location.engine.LocationEngineProxy
import org.maplibre.android.location.engine.LocationEngineRequest

class LocationEngineFactory {

    private var locationEngineRequest: LocationEngineRequest? = null

    private fun isGooglePlayServicesAvailable(context: Context): Boolean {
        return try {
            val availability = GoogleApiAvailability.getInstance()
            availability.isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
        } catch (e: Exception) {
            // GMS classes not available (e.g., HMS-only device)
            false
        }
    }

    fun getLocationEngine(context: Context): LocationEngine {
        if (locationEngineRequest?.priority == LocationEngineRequest.PRIORITY_HIGH_ACCURACY) {
            val locationEngineImpl = if (isGooglePlayServicesAvailable(context)) {
                GMSLocationEngine(context)
            } else {
                MapLibreGPSLocationEngine(context)
            }
            return LocationEngineProxy(locationEngineImpl)
        }
        return getDefaultLocationEngine(context)
    }

    fun initLocationComponent(
        context: Context,
        locationComponent: LocationComponent?,
        locationEngineRequest: LocationEngineRequest?
    ) {
        if (locationEngineRequest != null) {
            this.locationEngineRequest = locationEngineRequest
        }
        if (locationComponent != null) {
            locationComponent.locationEngine = getLocationEngine(context)
            locationEngineRequest?.let { locationEngineRequest ->
                locationComponent.locationEngineRequest = locationEngineRequest
            }
        }
    }
}
