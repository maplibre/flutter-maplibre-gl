// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.maplibre.maplibregl;

import android.graphics.PointF;
import android.util.Log;
import org.maplibre.geojson.Polygon;
import org.maplibre.android.camera.CameraPosition;
import org.maplibre.android.camera.CameraUpdate;
import org.maplibre.android.camera.CameraUpdateFactory;
import org.maplibre.android.geometry.LatLng;
import org.maplibre.android.geometry.LatLngBounds;
import org.maplibre.android.maps.MapLibreMap;
import org.maplibre.android.maps.Projection;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Readers of the JSON-like values that stay maps, such as layer and source properties, and the
 * camera sums behind the typed camera updates of {@link PigeonConvert}.
 */
class Convert {

  private static final String TAG = "Convert";

  static boolean toBoolean(Object o) {
    return (Boolean) o;
  }

  /**
   * Pans like maplibre-gl-js panBy: a positive {@code dx} moves the view east, a positive {@code
   * dy} south, both in logical pixels. MapLibreMap.scrollBy drags the content the other way and
   * moves the camera outside any CameraUpdate, so the caller had nothing to animate or report on.
   */
  static CameraUpdate scrollBy(MapLibreMap maplibreMap, double dx, double dy, float density) {
    final Projection projection = maplibreMap.getProjection();
    final PointF center = projection.toScreenLocation(maplibreMap.getCameraPosition().target);
    center.offset(toFractionalPixels(dx, density), toFractionalPixels(dy, density));
    return CameraUpdateFactory.newLatLng(projection.fromScreenLocation(center));
  }

  /**
   * Zooms by {@code amount} keeping the location under the focus, in logical pixels, where it is
   * on screen. CameraUpdateFactory.zoomBy(amount, point) recenters on the point instead.
   */
  static CameraUpdate zoomBy(
      MapLibreMap maplibreMap, double amount, double focusX, double focusY, float density) {
    final float focusPixelX = toFractionalPixels(focusX, density);
    final float focusPixelY = toFractionalPixels(focusY, density);
    final Projection projection = maplibreMap.getProjection();
    final CameraPosition camera = maplibreMap.getCameraPosition();
    final PointF center = projection.toScreenLocation(camera.target);
    final float scale = (float) Math.pow(2, -amount);
    final PointF target =
        new PointF(
            focusPixelX + (center.x - focusPixelX) * scale,
            focusPixelY + (center.y - focusPixelY) * scale);
    return CameraUpdateFactory.newCameraPosition(
        new CameraPosition.Builder(camera)
            .target(projection.fromScreenLocation(target))
            .zoom(camera.zoom + amount)
            .build());
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
  static CameraUpdate toBoundsCameraUpdate(
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
      // No camera came back to shift, for instance while the map has no size
      // yet. Let the SDK fit the bounds when the move runs, as before: the
      // bounds still land in the padded area, but the padding stays on as the
      // map padding after the move.
      return CameraUpdateFactory.newLatLngBounds(
          bounds,
          (int) (left * density),
          (int) (top * density),
          (int) (right * density),
          (int) (bottom * density));
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
   * does when it fits bounds. The longitude is wrapped into [-180, 180). iOS does the same sums.
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
    final double longitude = ((x / worldSize * 360) % 360 + 360) % 360 - 180;
    return new LatLng(
        Math.toDegrees(Math.atan(Math.sinh(Math.PI * (1 - 2 * y / worldSize)))), longitude);
  }

  static double toDouble(Object o) {
    return ((Number) o).doubleValue();
  }

  static float toFloat(Object o) {
    return ((Number) o).floatValue();
  }

  static int toInt(Object o) {
    return ((Number) o).intValue();
  }

  /**
   * {@code value}, a Dart int, as the int the platform API takes. Pigeon delivers every Dart int as
   * a long: one that does not fit in 32 bits fails the call, with code "error", rather than wrap
   * around.
   */
  static int toIntExact(long value) {
    final int narrowed = (int) value;
    if (narrowed != value) {
      throw new IllegalArgumentException(value + " does not fit in a 32-bit int.");
    }
    return narrowed;
  }

  /** The camera position of camera#onMove and camera#onIdle, with the fields of the map above. */
  static PgCameraPosition toPgCameraPosition(CameraPosition position) {
    if (position == null) {
      return null;
    }
    return new PgCameraPosition(
        position.bearing,
        new PgLatLng(position.target.getLatitude(), position.target.getLongitude()),
        position.tilt,
        position.zoom);
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

  /** {@code value}, in logical pixels, in physical pixels: a float, as the SDK takes them. */
  private static float toFractionalPixels(double value, float density) {
    return (float) value * density;
  }

  /** {@code value}, in logical pixels, in whole physical pixels, rounded towards zero. */
  static int toPixels(double value, float density) {
    return (int) toFractionalPixels(value, density);
  }

  static String toString(Object o) {
    return (String) o;
  }
}
