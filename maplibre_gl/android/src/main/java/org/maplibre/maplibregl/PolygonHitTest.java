package org.maplibre.maplibregl;

import org.maplibre.geojson.Feature;
import org.maplibre.geojson.Geometry;
import org.maplibre.geojson.MultiPolygon;
import org.maplibre.geojson.Point;
import org.maplibre.geojson.Polygon;

import java.util.ArrayList;
import java.util.List;

/**
 * Tells whether a polygon returned by a rendered-features query around a touch is really under the
 * finger. MapLibre Native tests each ring of a polygon on its own (upstream, in {@code
 * polygonIntersectsMultiPolygon}), so a box inside a hole still finds the polygon through its outer
 * ring (#893). MapLibre GL JS, on web, counts all rings together and skips the hole; this check
 * does the same for taps and drags. iOS has the same math in PolygonHitTest.swift: keep them in
 * step.
 *
 * <p>The math runs in Web Mercator world coordinates at the camera zoom. MapLibre tiles are 512 dp
 * wide, so one unit there is one dp on screen and ring edges compare directly with the touch
 * tolerance, with no projection call per vertex. Bearing does not change distances. With pitch the
 * scale varies across the screen, so the tolerance is approximate there.
 */
final class PolygonHitTest {
  private static final double MAX_LATITUDE = 85.0511287798066;

  private final double zoom;
  private final double touchX;
  private final double touchY;

  /** A touch at {@code lng}, {@code lat} with the camera at {@code zoom}. */
  PolygonHitTest(double lng, double lat, double zoom) {
    this.zoom = zoom;
    double[] touch = toWorld(lng, lat);
    this.touchX = touch[0];
    this.touchY = touch[1];
  }

  /**
   * Whether {@code feature}, returned for a square of half side {@code radiusDp} around the touch,
   * counts as hit. Only a polygon whose hole holds the touch is checked again: it counts when one of
   * its ring edges, outer or hole, is within {@code radiusDp}. Anything else stays as MapLibre
   * returned it: other geometries, a touch on the filled area, or one outside every ring, where the
   * native query already measures to the edges.
   */
  boolean keeps(Feature feature, double radiusDp) {
    List<List<Point>> rings = ringsOf(feature.geometry());
    if (rings.isEmpty()) return true;

    List<double[][]> projected = new ArrayList<>(rings.size());
    int containing = 0;
    for (List<Point> ring : rings) {
      double[][] world = new double[ring.size()][];
      for (int i = 0; i < world.length; i++) {
        Point p = ring.get(i);
        world[i] = toWorld(p.longitude(), p.latitude());
      }
      projected.add(world);
      if (contains(world)) containing++;
    }
    // Even-odd over all rings: an odd count is the filled area, zero is outside the polygon.
    if (containing == 0 || containing % 2 == 1) return true;

    // In a hole: hit only near its border, or the border of any other ring.
    double radiusSquared = radiusDp * radiusDp;
    for (double[][] ring : projected) {
      for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        if (distanceSquared(ring[j], ring[i]) <= radiusSquared) return true;
      }
    }
    return false;
  }

  private static List<List<Point>> ringsOf(Geometry geometry) {
    List<List<Point>> rings = new ArrayList<>();
    if (geometry instanceof Polygon) {
      rings.addAll(((Polygon) geometry).coordinates());
    } else if (geometry instanceof MultiPolygon) {
      for (List<List<Point>> polygon : ((MultiPolygon) geometry).coordinates()) {
        rings.addAll(polygon);
      }
    }
    return rings;
  }

  /** Web Mercator world coordinates, in dp, of a point at the camera zoom. */
  private double[] toWorld(double lng, double lat) {
    double worldSize = 512 * Math.pow(2, zoom);
    double clamped = Math.max(-MAX_LATITUDE, Math.min(MAX_LATITUDE, lat));
    double sin = Math.sin(Math.toRadians(clamped));
    double x = (lng + 180) / 360 * worldSize;
    double y = (0.5 - Math.log((1 + sin) / (1 - sin)) / (4 * Math.PI)) * worldSize;
    return new double[] {x, y};
  }

  /** Crossing test of the touch against one ring. */
  private boolean contains(double[][] ring) {
    boolean inside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      double[] a = ring[i];
      double[] b = ring[j];
      if ((a[1] > touchY) != (b[1] > touchY)
          && touchX < (b[0] - a[0]) * (touchY - a[1]) / (b[1] - a[1]) + a[0]) {
        inside = !inside;
      }
    }
    return inside;
  }

  /** Squared distance from the touch to the segment from {@code a} to {@code b}. */
  private double distanceSquared(double[] a, double[] b) {
    double dx = b[0] - a[0];
    double dy = b[1] - a[1];
    double lengthSquared = dx * dx + dy * dy;
    double t =
        lengthSquared == 0
            ? 0
            : Math.max(0, Math.min(1, ((touchX - a[0]) * dx + (touchY - a[1]) * dy) / lengthSquared));
    double ex = a[0] + t * dx - touchX;
    double ey = a[1] + t * dy - touchY;
    return ex * ex + ey * ey;
  }
}
