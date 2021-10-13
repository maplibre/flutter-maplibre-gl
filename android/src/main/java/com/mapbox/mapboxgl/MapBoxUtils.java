package com.mapbox.mapboxgl;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import com.mapbox.mapboxsdk.Mapbox;

abstract class MapBoxUtils {
    private static final String TAG = "MapboxMapController";

    static Mapbox getMapbox(Context context) {
        return Mapbox.getInstance(context);
    }
}
