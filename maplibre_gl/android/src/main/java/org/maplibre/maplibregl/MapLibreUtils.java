package org.maplibre.maplibregl;

import android.content.Context;
import org.maplibre.android.MapLibre;

abstract class MapLibreUtils {
  private static final String TAG = "MapLibreMapController";

  static MapLibre getMapLibre(Context context) {
    return MapLibre.getInstance(context);
  }
}
