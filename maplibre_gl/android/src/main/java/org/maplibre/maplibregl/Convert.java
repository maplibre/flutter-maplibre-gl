// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.maplibre.maplibregl;

import android.content.Context;
import android.graphics.Point;
import android.graphics.PointF;
import android.util.DisplayMetrics;
import android.util.Log;
import org.maplibre.android.location.engine.LocationEngineRequest;
import org.maplibre.geojson.Polygon;
import org.maplibre.android.camera.CameraPosition;
import org.maplibre.android.camera.CameraUpdate;
import org.maplibre.android.camera.CameraUpdateFactory;
import org.maplibre.android.geometry.LatLng;
import org.maplibre.android.geometry.LatLngBounds;
import org.maplibre.android.maps.MapLibreMap;
import org.maplibre.android.maps.Projection;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Conversions between JSON-like values and MapLibreMaps data types. */
class Convert {

  private static final String TAG = "Convert";

  static boolean toBoolean(Object o) {
    return (Boolean) o;
  }

  static CameraPosition toCameraPosition(Object o) {
    final Map<?, ?> data = toMap(o);
    final CameraPosition.Builder builder = new CameraPosition.Builder();
    builder.bearing(toFloat(data.get("bearing")));
    builder.target(toLatLng(data.get("target")));
    builder.tilt(toFloat(data.get("tilt")));
    builder.zoom(toFloat(data.get("zoom")));
    return builder.build();
  }

  static boolean isScrollByCameraUpdate(Object o) {
    return toString(toList(o).get(0)).equals("scrollBy");
  }

  static CameraUpdate toCameraUpdate(Object o, MapLibreMap maplibreMap, float density) {
    final List<?> data = toList(o);
    switch (toString(data.get(0))) {
      case "newCameraPosition":
        return CameraUpdateFactory.newCameraPosition(toCameraPosition(data.get(1)));
      case "newLatLng":
        return CameraUpdateFactory.newLatLng(toLatLng(data.get(1)));
      case "newLatLngBounds":
        return toBoundsCameraUpdate(
            maplibreMap,
            toLatLngBounds(data.get(1)),
            toDouble(data.get(2)),
            toDouble(data.get(3)),
            toDouble(data.get(4)),
            toDouble(data.get(5)),
            density);
      case "newLatLngZoom":
        return CameraUpdateFactory.newLatLngZoom(toLatLng(data.get(1)), toFloat(data.get(2)));
      case "scrollBy":
        {
          // Pans like maplibre-gl-js panBy: positive x moves the view east,
          // positive y south. MapLibreMap.scrollBy drags the content the other
          // way and moves the camera outside any CameraUpdate, so the caller
          // had nothing to animate or report on.
          final Projection projection = maplibreMap.getProjection();
          final PointF center =
              projection.toScreenLocation(maplibreMap.getCameraPosition().target);
          center.offset(
              toFractionalPixels(data.get(1), density), toFractionalPixels(data.get(2), density));
          return CameraUpdateFactory.newLatLng(projection.fromScreenLocation(center));
        }
      case "zoomBy":
        if (data.size() == 2) {
          return CameraUpdateFactory.zoomBy(toFloat(data.get(1)));
        } else {
          // Keeps the point under the focus where it is on screen.
          // CameraUpdateFactory.zoomBy(amount, point) recenters on the point.
          final float amount = toFloat(data.get(1));
          final List<?> focusData = toList(data.get(2));
          final float focusX = toFractionalPixels(focusData.get(0), density);
          final float focusY = toFractionalPixels(focusData.get(1), density);
          final Projection projection = maplibreMap.getProjection();
          final CameraPosition camera = maplibreMap.getCameraPosition();
          final PointF center = projection.toScreenLocation(camera.target);
          final float scale = (float) Math.pow(2, -amount);
          final PointF target =
              new PointF(
                  focusX + (center.x - focusX) * scale, focusY + (center.y - focusY) * scale);
          return CameraUpdateFactory.newCameraPosition(
              new CameraPosition.Builder(camera)
                  .target(projection.fromScreenLocation(target))
                  .zoom(camera.zoom + amount)
                  .build());
        }
      case "zoomIn":
        return CameraUpdateFactory.zoomIn();
      case "zoomOut":
        return CameraUpdateFactory.zoomOut();
      case "zoomTo":
        return CameraUpdateFactory.zoomTo(toFloat(data.get(1)));
      case "bearingTo":
        return CameraUpdateFactory.bearingTo(toFloat(data.get(1)));
      case "tiltTo":
        return CameraUpdateFactory.tiltTo(toFloat(data.get(1)));
      default:
        throw new IllegalArgumentException("Cannot interpret " + o + " as CameraUpdate");
    }
  }

  /**
   * Fits the bounds inside the map padding plus the given padding (in logical pixels), with the
   * bounds in the middle of the padded area, as maplibre-gl-js fitBounds and iOS do.
   *
   * <p>CameraUpdateFactory.newLatLngBounds puts the padding in the camera position it moves to, so
   * it stays on as the map padding after the move and every later camera target is the center of
   * the padded area (#1047). Here the center is shifted instead, and the camera position carries
   * no padding, so the map keeps its own.
   */
  private static CameraUpdate toBoundsCameraUpdate(
      MapLibreMap maplibreMap,
      LatLngBounds bounds,
      double left,
      double top,
      double right,
      double bottom,
      float density) {
    final double[] mapPadding = maplibreMap.getCameraPosition().padding;
    final double[] padding = {left, top, right, bottom};
    final int[] fitPadding = new int[4];
    for (int i = 0; i < 4; i++) {
      final double mapSide = mapPadding != null && mapPadding.length == 4 ? mapPadding[i] : 0;
      fitPadding[i] = (int) (padding[i] * density + mapSide);
    }
    final CameraPosition fit = maplibreMap.getCameraForLatLngBounds(bounds, fitPadding);
    if (fit == null || fit.target == null) {
      return null;
    }
    return CameraUpdateFactory.newCameraPosition(
        new CameraPosition.Builder()
            .target(
                offset(fit.target, fit.zoom, fit.bearing, (right - left) / 2, (bottom - top) / 2))
            .zoom(fit.zoom)
            .bearing(fit.bearing)
            .tilt(fit.tilt)
            .build());
  }

  /**
   * The coordinate dx logical pixels right and dy down on screen from center, for a camera at zoom
   * facing bearing, in Web Mercator with 512 pixel tiles. The tilt is left out, as maplibre-gl-js
   * does when it fits bounds. iOS does the same sums.
   */
  static LatLng offset(LatLng center, double zoom, double bearing, double dx, double dy) {
    final double worldSize = 512 * Math.pow(2, zoom);
    final double radians = Math.toRadians(bearing);
    final double offsetX = dx * Math.cos(radians) - dy * Math.sin(radians);
    final double offsetY = dx * Math.sin(radians) + dy * Math.cos(radians);
    final double sinLatitude = Math.sin(Math.toRadians(center.getLatitude()));
    final double x = (center.getLongitude() + 180) / 360 * worldSize + offsetX;
    final double y =
        (0.5 - Math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * Math.PI)) * worldSize
            + offsetY;
    return new LatLng(
        Math.toDegrees(Math.atan(Math.sinh(Math.PI * (1 - 2 * y / worldSize)))),
        x / worldSize * 360 - 180);
  }

  static double toDouble(Object o) {
    return ((Number) o).doubleValue();
  }

  static float toFloat(Object o) {
    return ((Number) o).floatValue();
  }

  static Float toFloatWrapper(Object o) {
    return (o == null) ? null : toFloat(o);
  }

  static int toInt(Object o) {
    return ((Number) o).intValue();
  }

  static Object toJson(CameraPosition position) {
    if (position == null) {
      return null;
    }
    final Map<String, Object> data = new HashMap<>();
    data.put("bearing", position.bearing);
    data.put("target", toJson(position.target));
    data.put("tilt", position.tilt);
    data.put("zoom", position.zoom);
    return data;
  }

  private static Object toJson(LatLng latLng) {
    return Arrays.asList(latLng.getLatitude(), latLng.getLongitude());
  }

  static LatLng toLatLng(Object o) {
    final List<?> data = toList(o);
    return new LatLng(toDouble(data.get(0)), toDouble(data.get(1)));
  }

  static LatLngBounds toLatLngBounds(Object o) {
    if (o == null) {
      return null;
    }
    final List<?> data = toList(o);
    LatLng[] boundsArray = new LatLng[] {toLatLng(data.get(0)), toLatLng(data.get(1))};
    List<LatLng> bounds = Arrays.asList(boundsArray);
    LatLngBounds.Builder builder = new LatLngBounds.Builder();
    builder.includes(bounds);
    return builder.build();
  }

static LocationEngineRequest toLocationEngineRequest(Object o) {
  if (o == null) {
    return null;
  }
  List<?> data = toList(o);
  return new LocationEngineRequest.Builder(toInt(data.get(0)))
          .setPriority(toInt(data.get(1)))
          .setDisplacement(toInt(data.get(2)))
          .build();
}

  static List<LatLng> toLatLngList(Object o, boolean flippedOrder) {
    if (o == null) {
      return null;
    }
    final List<?> data = toList(o);
    List<LatLng> latLngList = new ArrayList<>();
    for (int i = 0; i < data.size(); i++) {
      final List<?> coords = toList(data.get(i));
      if (flippedOrder) {
        latLngList.add(new LatLng(toDouble(coords.get(1)), toDouble(coords.get(0))));
      } else {
        latLngList.add(new LatLng(toDouble(coords.get(0)), toDouble(coords.get(1))));
      }
    }
    return latLngList;
  }

  private static List<List<LatLng>> toLatLngListList(Object o) {
    if (o == null) {
      return null;
    }
    final List<?> data = toList(o);
    List<List<LatLng>> latLngListList = new ArrayList<>();
    for (int i = 0; i < data.size(); i++) {
      List<LatLng> latLngList = toLatLngList(data.get(i), false);
      latLngListList.add(latLngList);
    }
    return latLngListList;
  }

  static Polygon interpretListLatLng(List<List<LatLng>> geometry) {
    List<List<org.maplibre.geojson.Point>> points = new ArrayList<>(geometry.size());
    for (List<LatLng> innerGeometry : geometry) {
      List<org.maplibre.geojson.Point> innerPoints = new ArrayList<>(innerGeometry.size());
      for (LatLng latLng : innerGeometry) {
        innerPoints.add(
            org.maplibre.geojson.Point.fromLngLat(latLng.getLongitude(), latLng.getLatitude()));
      }
      points.add(innerPoints);
    }
    return Polygon.fromLngLats(points);
  }

  static List<?> toList(Object o) {
    return (List<?>) o;
  }

  static long toLong(Object o) {
    return ((Number) o).longValue();
  }

  static Map<?, ?> toMap(Object o) {
    return (Map<?, ?>) o;
  }

  private static float toFractionalPixels(Object o, float density) {
    return toFloat(o) * density;
  }

  static int toPixels(Object o, float density) {
    return (int) toFractionalPixels(o, density);
  }

  private static Point toPoint(Object o, float density) {
    final List<?> data = toList(o);
    return new Point(toPixels(data.get(0), density), toPixels(data.get(1), density));
  }

  static String toString(Object o) {
    return (String) o;
  }

  static void interpretMapLibreMapOptions(Object o, MapLibreMapOptionsSink sink, Context context) {
    final DisplayMetrics metrics = context.getResources().getDisplayMetrics();
    final Map<?, ?> data = toMap(o);

    final Object locationEngineProperties = data.get("locationEngineProperties");
    if (locationEngineProperties != null) {
      final List<?> locationEnginePropertiesList = toList(locationEngineProperties);
        sink.setLocationEngineProperties(toLocationEngineRequest(locationEnginePropertiesList));
    }
    final Object locationSource = data.get("locationSource");
    if (locationSource != null) {
      sink.setLocationSource(toString(locationSource));
    }
    final Object cameraTargetBounds = data.get("cameraTargetBounds");
    if (cameraTargetBounds != null) {
      final List<?> targetData = toList(cameraTargetBounds);
      sink.setCameraTargetBounds(toLatLngBounds(targetData.get(0)));
    }
    final Object compassEnabled = data.get("compassEnabled");
    if (compassEnabled != null) {
      sink.setCompassEnabled(toBoolean(compassEnabled));
    }
    final Object styleString = data.get("styleString");
    if (styleString != null) {
      sink.setStyleString(toString(styleString));
    }
    final Object minMaxZoomPreference = data.get("minMaxZoomPreference");
    if (minMaxZoomPreference != null) {
      final List<?> zoomPreferenceData = toList(minMaxZoomPreference);
      sink.setMinMaxZoomPreference( //
          toFloatWrapper(zoomPreferenceData.get(0)), //
          toFloatWrapper(zoomPreferenceData.get(1)));
    }
    final Object rotateGesturesEnabled = data.get("rotateGesturesEnabled");
    if (rotateGesturesEnabled != null) {
      sink.setRotateGesturesEnabled(toBoolean(rotateGesturesEnabled));
    }
    final Object scrollGesturesEnabled = data.get("scrollGesturesEnabled");
    if (scrollGesturesEnabled != null) {
      sink.setScrollGesturesEnabled(toBoolean(scrollGesturesEnabled));
    }
    final Object tiltGesturesEnabled = data.get("tiltGesturesEnabled");
    if (tiltGesturesEnabled != null) {
      sink.setTiltGesturesEnabled(toBoolean(tiltGesturesEnabled));
    }
    final Object panInertia = data.get("panInertia");
    if (panInertia != null) {
      sink.setPanInertia(toInt(panInertia));
    }
    final Object trackCameraPosition = data.get("trackCameraPosition");
    if (trackCameraPosition != null) {
      sink.setTrackCameraPosition(toBoolean(trackCameraPosition));
    }
    final Object zoomGesturesEnabled = data.get("zoomGesturesEnabled");
    if (zoomGesturesEnabled != null) {
      sink.setZoomGesturesEnabled(toBoolean(zoomGesturesEnabled));
    }
    final Object doubleClickZoomEnabled = data.get("doubleClickZoomEnabled");
    if (doubleClickZoomEnabled != null) {
      sink.setDoubleClickZoomEnabled(toBoolean(doubleClickZoomEnabled));
    }
    final Object myLocationEnabled = data.get("myLocationEnabled");
    if (myLocationEnabled != null) {
      sink.setMyLocationEnabled(toBoolean(myLocationEnabled));
    }
    final Object myLocationTrackingMode = data.get("myLocationTrackingMode");
    if (myLocationTrackingMode != null) {
      sink.setMyLocationTrackingMode(toInt(myLocationTrackingMode));
    }
    final Object myLocationRenderMode = data.get("myLocationRenderMode");
    if (myLocationRenderMode != null) {
      sink.setMyLocationRenderMode(toInt(myLocationRenderMode));
    }
    final Object logoEnabled = data.get("logoEnabled");
    if (logoEnabled != null) {
      sink.setLogoEnabled(toBoolean(logoEnabled));
    }
    final Object logoViewGravity = data.get("logoViewPosition");
    if (logoViewGravity != null) {
      sink.setLogoViewGravity(toInt(logoViewGravity));
    }
    final Object logoViewMargins = data.get("logoViewMargins");
    if (logoViewMargins != null) {
      final List logoViewMarginsData = toList(logoViewMargins);
      final Point point = toPoint(logoViewMarginsData, metrics.density);
      sink.setLogoViewMargins(point.x, point.y);
    }
    final Object compassGravity = data.get("compassViewPosition");
    if (compassGravity != null) {
      sink.setCompassGravity(toInt(compassGravity));
    }
    final Object compassViewMargins = data.get("compassViewMargins");
    if (compassViewMargins != null) {
      final List compassViewMarginsData = toList(compassViewMargins);
      final Point point = toPoint(compassViewMarginsData, metrics.density);
      sink.setCompassViewMargins(point.x, point.y);
    }
    final Object attributionButtonGravity = data.get("attributionButtonPosition");
    if (attributionButtonGravity != null) {
      sink.setAttributionButtonGravity(toInt(attributionButtonGravity));
    }
    final Object attributionButtonMargins = data.get("attributionButtonMargins");
    if (attributionButtonMargins != null) {
      final List attributionButtonMarginsData = toList(attributionButtonMargins);
      final Point point = toPoint(attributionButtonMarginsData, metrics.density);
      sink.setAttributionButtonMargins(point.x, point.y);
    }
    final Object attributionButtonColor = data.get("attributionButtonColor");
    if (attributionButtonColor != null) {
      sink.setAttributionButtonColor(toInt(attributionButtonColor));
    }
    final Object foregroundLoadColor = data.get("foregroundLoadColor");
    if (foregroundLoadColor != null) {
      sink.setForegroundLoadColor(toInt(foregroundLoadColor));
    }
    final Object useHybridComposition = data.get("useHybridComposition");
    if (useHybridComposition != null) {
      sink.setUseHybridComposition(toBoolean(useHybridComposition));
    }
    final Object translucentTextureSurface = data.get("translucentTextureSurface");
    if (translucentTextureSurface != null) {
      sink.setTranslucentTextureSurface(toBoolean(translucentTextureSurface));
    }
    final Object featureTapsTriggersMapClick = data.get("featureTapsTriggersMapClick");
    if (featureTapsTriggersMapClick != null) {
      sink.setFeatureTapsTriggersMapClick(toBoolean(featureTapsTriggersMapClick));
    }
    final Object symbolPlacementTransitionsEnabled = data.get("symbolPlacementTransitionsEnabled");
    if (symbolPlacementTransitionsEnabled != null) {
      sink.setSymbolPlacementTransitionsEnabled(toBoolean(symbolPlacementTransitionsEnabled));
    }
  }
}
