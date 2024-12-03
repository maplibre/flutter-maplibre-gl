package org.maplibre.maplibregl;

import android.annotation.SuppressLint;
import android.app.PendingIntent;
import android.content.Context;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import org.maplibre.android.location.engine.LocationEngineCallback;
import org.maplibre.android.location.engine.LocationEngineRequest;
import org.maplibre.android.location.engine.LocationEngineResult;
import org.maplibre.android.location.engine.LocationEngineImpl;


public class MapLibreGPSLocationEngine implements LocationEngineImpl<LocationListener> {
    private static final String TAG = "GPSLocationEngine";
    final LocationManager locationManager;

    String currentProvider = LocationManager.PASSIVE_PROVIDER;

    public MapLibreGPSLocationEngine(@NonNull Context context) {
        locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
    }

    @NonNull
    @Override
    public LocationListener createListener(LocationEngineCallback<LocationEngineResult> callback) {
        return new AndroidLocationEngineCallbackTransport(callback);
    }

    @Override
    public void getLastLocation(@NonNull LocationEngineCallback<LocationEngineResult> callback)
            throws SecurityException {
        Location lastLocation = getLastLocationFor(currentProvider);
        if (lastLocation != null) {
            callback.onSuccess(LocationEngineResult.create(lastLocation));
            return;
        }

        for (String provider : locationManager.getAllProviders()) {
            lastLocation = getLastLocationFor(provider);
            if (lastLocation != null) {
                callback.onSuccess(LocationEngineResult.create(lastLocation));
                return;
            }
        }
        callback.onFailure(new Exception("Last location unavailable"));
    }

    @SuppressLint("MissingPermission")
    Location getLastLocationFor(String provider) throws SecurityException {
        Location location = null;
        try {
            location = locationManager.getLastKnownLocation(provider);
        } catch (IllegalArgumentException iae) {
            Log.e(TAG, iae.toString());
        }
        return location;
    }

    @SuppressLint("MissingPermission")
    @Override
    public void requestLocationUpdates(@NonNull LocationEngineRequest request,
                                       @NonNull LocationListener listener,
                                       @Nullable Looper looper) throws SecurityException {
        currentProvider = getBestProvider(request.getPriority());
        locationManager.requestLocationUpdates(currentProvider, request.getInterval(), request.getDisplacement(),
                listener, looper);
    }

    @SuppressLint("MissingPermission")
    @Override
    public void requestLocationUpdates(@NonNull LocationEngineRequest request,
                                       @NonNull PendingIntent pendingIntent) throws SecurityException {
        currentProvider = getBestProvider(request.getPriority());
        locationManager.requestLocationUpdates(currentProvider, request.getInterval(),
                request.getDisplacement(), pendingIntent);
    }

    @SuppressLint("MissingPermission")
    @Override
    public void removeLocationUpdates(@NonNull LocationListener listener) {
        if (listener != null) {
            locationManager.removeUpdates(listener);
        }
    }

    @Override
    public void removeLocationUpdates(PendingIntent pendingIntent) {
        if (pendingIntent != null) {
            locationManager.removeUpdates(pendingIntent);
        }
    }

    private String getBestProvider(int priority) {
        String provider = null;
        if (priority != LocationEngineRequest.PRIORITY_NO_POWER) {
            provider = LocationManager.GPS_PROVIDER;
        }
        return provider != null ? provider : LocationManager.PASSIVE_PROVIDER;
    }


    @VisibleForTesting
    static final class AndroidLocationEngineCallbackTransport implements LocationListener {
        private final LocationEngineCallback<LocationEngineResult> callback;

        AndroidLocationEngineCallbackTransport(LocationEngineCallback<LocationEngineResult> callback) {
            this.callback = callback;
        }

        @Override
        public void onLocationChanged(Location location) {
            callback.onSuccess(LocationEngineResult.create(location));
        }

        @Override
        public void onStatusChanged(String s, int i, Bundle bundle) {
            // noop
        }

        @Override
        public void onProviderEnabled(String s) {
            // noop
        }

        @Override
        public void onProviderDisabled(String s) {
            callback.onFailure(new Exception("Current provider disabled"));
        }
    }
}
