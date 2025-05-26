package org.maplibre.maplibregl

import android.content.Context
import org.maplibre.android.location.LocationComponent
import org.maplibre.android.location.engine.LocationEngine
import org.maplibre.android.location.engine.LocationEngineDefault.getDefaultLocationEngine
import org.maplibre.android.location.engine.LocationEngineProxy
import org.maplibre.android.location.engine.LocationEngineRequest

class LocationEngineFactory {

    private var locationEngineRequest: LocationEngineRequest? = null

    fun getLocationEngine(context: Context): LocationEngine {
        if (locationEngineRequest?.priority == LocationEngineRequest.PRIORITY_HIGH_ACCURACY) {
            return LocationEngineProxy(
                GMSServicesLocationEngine(context)
            )
        }
        return getDefaultLocationEngine(context)
    }

    fun initLocationComponent(
        context: Context,
        locationComponent: LocationComponent?,
        locationEngineRequest: LocationEngineRequest?
    ) {
        if(locationEngineRequest != null){
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
