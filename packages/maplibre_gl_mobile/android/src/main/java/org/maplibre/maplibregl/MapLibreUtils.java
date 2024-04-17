package org.maplibre.maplibregl;

import android.content.Context;
import com.mapbox.mapboxsdk.Mapbox;

abstract class MapLibreUtils {
  private static final String TAG = "MapboxMapController";

  static Mapbox getMapbox(Context context) {
    return Mapbox.getInstance(context);
  }
}
