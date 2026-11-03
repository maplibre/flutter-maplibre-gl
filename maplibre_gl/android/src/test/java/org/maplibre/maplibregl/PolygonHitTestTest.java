package org.maplibre.maplibregl;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.maplibre.geojson.Feature;
import org.maplibre.geojson.MultiPolygon;
import org.maplibre.geojson.Point;
import org.maplibre.geojson.Polygon;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * The cases PolygonHitTest must pass. PolygonHitTest.swift runs the same math on iOS: change both
 * together, with the same fixtures. At zoom 10 one degree of longitude is about 1456 dp at the
 * equator, so a touch 0.001 degrees from an edge is about 1.5 dp away and one 0.01 degrees away
 * about 15 dp.
 */
public class PolygonHitTestTest {
  private static final double ZOOM = 10;
  private static final double RADIUS = 8;

  /** A square from -1 to 1 with a square hole from -0.5 to 0.5. */
  private static final List<List<Point>> SQUARE_WITH_HOLE =
      Arrays.asList(square(-1, -1, 1, 1), square(-0.5, -0.5, 0.5, 0.5));

  private static boolean keeps(double lng, double lat, Feature feature) {
    return new PolygonHitTest(lng, lat, ZOOM).keeps(feature, RADIUS);
  }

  private static Feature polygon(List<List<Point>> rings) {
    return Feature.fromGeometry(Polygon.fromLngLats(rings));
  }

  private static Feature multiPolygon(List<List<List<Point>>> polygons) {
    return Feature.fromGeometry(MultiPolygon.fromLngLats(polygons));
  }

  /** A closed ring through {@code lngLats}, given as lng, lat pairs. */
  private static List<Point> ring(double... lngLats) {
    List<Point> points = open(lngLats);
    points.add(points.get(0));
    return points;
  }

  /** A ring through {@code lngLats} without the closing point. */
  private static List<Point> open(double... lngLats) {
    List<Point> points = new ArrayList<>();
    for (int i = 0; i < lngLats.length; i += 2) {
      points.add(Point.fromLngLat(lngLats[i], lngLats[i + 1]));
    }
    return points;
  }

  private static List<Point> square(double west, double south, double east, double north) {
    return ring(west, south, east, south, east, north, west, north);
  }

  @Test
  public void touchInHoleFarFromEdgesIsNotKept() {
    assertFalse(keeps(0, 0, polygon(SQUARE_WITH_HOLE)));
    // 0.01 degrees, about 15 dp, is past the radius.
    assertFalse(keeps(0.49, 0, polygon(SQUARE_WITH_HOLE)));
  }

  @Test
  public void touchInHoleWithinRadiusOfEdgeIsKept() {
    assertTrue(keeps(0.499, 0, polygon(SQUARE_WITH_HOLE)));
    assertTrue(keeps(0, -0.499, polygon(SQUARE_WITH_HOLE)));
  }

  @Test
  public void touchOnFilledAreaIsKept() {
    assertTrue(keeps(0.75, 0, polygon(SQUARE_WITH_HOLE)));
  }

  @Test
  public void touchOutsideAllRingsIsKept() {
    assertTrue(keeps(1.5, 0, polygon(SQUARE_WITH_HOLE)));
  }

  @Test
  public void touchLongitudeIsWrapped() {
    assertFalse(keeps(360, 0, polygon(SQUARE_WITH_HOLE)));
    assertFalse(keeps(-360, 0, polygon(SQUARE_WITH_HOLE)));
    assertTrue(keeps(360.75, 0, polygon(SQUARE_WITH_HOLE)));
  }

  @Test
  public void polygonWithoutHoleIsKept() {
    assertTrue(keeps(0, 0, polygon(Arrays.asList(square(-1, -1, 1, 1)))));
  }

  @Test
  public void otherGeometriesAreKept() {
    assertTrue(keeps(0, 0, Feature.fromGeometry(Point.fromLngLat(5, 5))));
  }

  @Test
  public void vertexAtTouchLatitude() {
    // Diamonds: the outer and hole rings both have vertices on the equator, where the touches are.
    Feature diamond =
        polygon(
            Arrays.asList(
                ring(0, -1, 1, 0, 0, 1, -1, 0), ring(0, -0.5, 0.5, 0, 0, 0.5, -0.5, 0)));
    assertFalse(keeps(0, 0, diamond));
    assertTrue(keeps(0.75, 0, diamond));
    assertTrue(keeps(-0.75, 0, diamond));
    assertTrue(keeps(1.5, 0, diamond));
  }

  @Test
  public void horizontalEdgeAtTouchLatitude() {
    // An L-shaped hole with an edge along the equator, east of the touch.
    Feature notched =
        polygon(
            Arrays.asList(
                square(-1, -1, 1, 1),
                ring(-0.5, -0.5, 0.5, -0.5, 0.5, 0, 0.2, 0, 0.2, 0.5, -0.5, 0.5)));
    assertFalse(keeps(-0.2, 0, notched));
    assertFalse(keeps(0.35, -0.25, notched));
    assertTrue(keeps(0.35, 0.25, notched));
  }

  @Test
  public void islandInsideHoleIsKept() {
    Feature island =
        multiPolygon(
            Arrays.asList(SQUARE_WITH_HOLE, Arrays.asList(square(-0.1, -0.1, 0.1, 0.1))));
    assertTrue(keeps(0, 0, island));
    assertFalse(keeps(0.3, 0, island));
  }

  @Test
  public void overlappingPartsAreKept() {
    // The second part covers the filled area of the first: two rings contain the touch, yet
    // it is on the fill, not in a hole.
    Feature overlapping =
        multiPolygon(
            Arrays.asList(SQUARE_WITH_HOLE, Arrays.asList(square(0.6, -0.2, 2, 0.2))));
    assertTrue(keeps(0.8, 0, overlapping));
    assertFalse(keeps(0, 0, overlapping));

    Feature withoutHoles =
        multiPolygon(
            Arrays.asList(
                Arrays.asList(square(-1, -1, 1, 1)), Arrays.asList(square(0, 0, 2, 2))));
    assertTrue(keeps(0.5, 0.5, withoutHoles));
  }

  @Test
  public void closingDuplicatePointMakesNoDifference() {
    Feature closed = polygon(SQUARE_WITH_HOLE);
    Feature unclosed =
        polygon(
            Arrays.asList(
                open(-1, -1, 1, -1, 1, 1, -1, 1), open(-0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5)));
    for (Feature feature : Arrays.asList(closed, unclosed)) {
      assertFalse(keeps(0, 0, feature));
      // Near the edge that closes the ring, from the last point back to the first.
      assertTrue(keeps(-0.499, 0, feature));
      // Near the vertex the closing point repeats.
      assertTrue(keeps(-0.499, -0.499, feature));
    }
  }
}
