package org.maplibre.maplibregl;

import android.content.Context;
import org.maplibre.android.MapLibre;

abstract class MapLibreUtils {
  private static final String TAG = "MapboxMapController";

  static MapLibre getMapbox(Context context) {
    return MapLibre.getInstance(context);
  }
}
