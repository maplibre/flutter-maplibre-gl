package com.mapbox.mapboxgl;

import android.content.Context;
import com.mapbox.mapboxsdk.Mapbox;

abstract class MapBoxUtils {
  private static final String TAG = "MapboxMapController";

  static Mapbox getMapbox(Context context) {
    return Mapbox.getInstance(context);
  }
}
