package org.maplibre.maplibregl;

import android.annotation.SuppressLint;
import android.app.PendingIntent;
import android.content.Context;
import android.location.Location;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationAvailability;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;

import org.maplibre.android.location.engine.LocationEngineCallback;
import org.maplibre.android.location.engine.LocationEngineImpl;
import org.maplibre.android.location.engine.LocationEngineRequest;
import org.maplibre.android.location.engine.LocationEngineResult;

/**
 * A MapLibre LocationEngine implementation using Google Play Services.
 */
public class GMSLocationEngine implements LocationEngineImpl<LocationCallback> {
    private static final String TAG = "GMSLocationEngine";
    private final FusedLocationProviderClient fusedLocationProviderClient;

    public GMSLocationEngine(@NonNull Context context) {
        fusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(context);
    }

    @NonNull
    @Override
    public LocationCallback createListener(LocationEngineCallback<LocationEngineResult> callback) {
        return new GooglePlayServicesLocationCallbackTransport(callback);
    }

    @SuppressLint("MissingPermission")
    @Override
    public void getLastLocation(@NonNull final LocationEngineCallback<LocationEngineResult> callback)
            throws SecurityException {
        fusedLocationProviderClient.getLastLocation()
                .addOnSuccessListener(location -> {
                    if (location != null) {
                        callback.onSuccess(LocationEngineResult.create(location));
                    } else {
                        callback.onFailure(new Exception("Last location unavailable"));
                    }
                })
                .addOnFailureListener(callback::onFailure);
    }

    @SuppressLint("MissingPermission")
    @Override
    public void requestLocationUpdates(@NonNull LocationEngineRequest request,
                                       @NonNull LocationCallback listener,
                                       @Nullable Looper looper) throws SecurityException {
        LocationRequest googleLocationRequest = createGoogleLocationRequest(request);
        fusedLocationProviderClient.requestLocationUpdates(googleLocationRequest, listener, looper);
    }

    @SuppressLint("MissingPermission")
    @Override
    public void requestLocationUpdates(@NonNull LocationEngineRequest request,
                                       @NonNull PendingIntent pendingIntent) throws SecurityException {
        LocationRequest googleLocationRequest = createGoogleLocationRequest(request);
        fusedLocationProviderClient.requestLocationUpdates(googleLocationRequest, pendingIntent);
    }

    @Override
    public void removeLocationUpdates(@NonNull LocationCallback listener) {
        fusedLocationProviderClient.removeLocationUpdates(listener);
    }

    @Override
    public void removeLocationUpdates(PendingIntent pendingIntent) {
        if (pendingIntent != null) {
            fusedLocationProviderClient.removeLocationUpdates(pendingIntent);
        }
    }

    /**
     * Converts a MapLibre {@link LocationEngineRequest} to a Google Play Services {@link LocationRequest}.
     *
     * @param engineRequest The MapLibre location request.
     * @return The Google Play Services location request.
     */
    private LocationRequest createGoogleLocationRequest(@NonNull LocationEngineRequest engineRequest) {
        LocationRequest.Builder builder = new LocationRequest.Builder(
                mapPriority(engineRequest.getPriority()),
                engineRequest.getInterval()
        );

        builder.setMinUpdateIntervalMillis(engineRequest.getFastestInterval());
        builder.setMinUpdateDistanceMeters(engineRequest.getDisplacement());
        // 'maxWaitTime' in LocationEngineRequest corresponds to 'maxUpdateDelayMillis' in LocationRequest for batching.
        // If engineRequest.getMaxWaitTime() is 0, it means no batching or the default behavior.
        // Google's LocationRequest sets maxUpdateDelayMillis to interval * 2 by default if not set.
        // We only set it if maxWaitTime is explicitly positive.
        if (engineRequest.getMaxWaitTime() > 0) {
            builder.setMaxUpdateDelayMillis(engineRequest.getMaxWaitTime());
        }

        return builder.build();
    }

    /**
     * Maps MapLibre LocationEngineRequest priorities to Google Play Services LocationRequest priorities.
     *
     * @param enginePriority The priority from {@link LocationEngineRequest}.
     * @return The corresponding priority for {@link LocationRequest}.
     */
    private int mapPriority(int enginePriority) {
        switch (enginePriority) {
            case LocationEngineRequest.PRIORITY_HIGH_ACCURACY:
                return Priority.PRIORITY_HIGH_ACCURACY;
            case LocationEngineRequest.PRIORITY_BALANCED_POWER_ACCURACY:
                return Priority.PRIORITY_BALANCED_POWER_ACCURACY;
            case LocationEngineRequest.PRIORITY_LOW_POWER:
                return Priority.PRIORITY_LOW_POWER;
            case LocationEngineRequest.PRIORITY_NO_POWER:
                return Priority.PRIORITY_PASSIVE;
            default:
                Log.w(TAG, "Unknown MapLibre priority: " + enginePriority + ". Defaulting to BALANCED_POWER_ACCURACY.");
                return Priority.PRIORITY_BALANCED_POWER_ACCURACY; // Default fallback
        }
    }

    /**
     * Internal class to transport Google Play Services LocationCallback events
     * to the MapLibre LocationEngineCallback.
     */
    @VisibleForTesting
    static final class GooglePlayServicesLocationCallbackTransport extends LocationCallback {
        private final LocationEngineCallback<LocationEngineResult> callback;

        GooglePlayServicesLocationCallbackTransport(LocationEngineCallback<LocationEngineResult> callback) {
            this.callback = callback;
        }

        @Override
        public void onLocationResult(@NonNull LocationResult locationResult) {
            super.onLocationResult(locationResult);
            Location lastLocation = locationResult.getLastLocation();
            if (lastLocation != null) {
                callback.onSuccess(LocationEngineResult.create(lastLocation));
            } else {
                // This case should ideally not happen if locations are being delivered,
                // but handle defensively.
                Log.w(TAG, "onLocationResult received but getLastLocation was null.");
                // Consider if a failure should be propagated here or if it's implicitly handled
                // by no onSuccess calls. For now, just log.
            }
        }

        @Override
        public void onLocationAvailability(@NonNull LocationAvailability locationAvailability) {
            super.onLocationAvailability(locationAvailability);
            if (!locationAvailability.isLocationAvailable()) {
                // This callback indicates that location is not available, which can be
                // treated as a failure or a temporary state.
                // For simplicity, we'll forward this as a failure, similar to onProviderDisabled.
                callback.onFailure(new Exception("Location not available. " +
                        "Check location settings and permissions."));
            }
        }
    }
}
