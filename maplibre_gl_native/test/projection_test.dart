import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_native/src/utils/projection.dart';

/// Reference values from `mbgl::Projection::getMetersPerPixelAtLatitude`.
/// Keeping them as literals (rather than recomputing the formula in the test)
/// is the point: it is what would catch a drift from upstream.
void main() {
  group('MercatorProjection.metersPerPixel', () {
    test(
      'equator at zoom 0 is the world circumference over one world tile',
      () {
        // 2 * pi * 6378137 / 512
        expect(
          MercatorProjection.metersPerPixel(0, 0),
          closeTo(78271.51696402048, 1e-9),
        );
      },
    );

    test('halves for every zoom level', () {
      final z10 = MercatorProjection.metersPerPixel(0, 10);
      final z11 = MercatorProjection.metersPerPixel(0, 11);
      expect(z11, closeTo(z10 / 2, 1e-9));
    });

    test('shrinks with the cosine of the latitude', () {
      expect(
        MercatorProjection.metersPerPixel(60, 0),
        closeTo(MercatorProjection.metersPerPixel(0, 0) * 0.5, 1e-6),
      );
    });

    test('is symmetric across the equator', () {
      expect(
        MercatorProjection.metersPerPixel(-45, 7),
        closeTo(MercatorProjection.metersPerPixel(45, 7), 1e-12),
      );
    });

    test('clamps the latitude to the projection limit', () {
      // The Android and iOS backends clamp to LATITUDE_MAX, so 89 degrees
      // must NOT keep shrinking past it.
      expect(
        MercatorProjection.metersPerPixel(89, 4),
        closeTo(MercatorProjection.metersPerPixel(MapLimits.latitudeMax, 4), 0),
      );
      expect(
        MercatorProjection.metersPerPixel(-89, 4),
        closeTo(MercatorProjection.metersPerPixel(MapLimits.latitudeMax, 4), 0),
      );
    });

    test('clamps the zoom to the camera range', () {
      expect(
        MercatorProjection.metersPerPixel(0, -3),
        closeTo(MercatorProjection.metersPerPixel(0, MapLimits.minZoom), 0),
      );
      expect(
        MercatorProjection.metersPerPixel(0, 30),
        closeTo(MercatorProjection.metersPerPixel(0, MapLimits.maxZoom), 0),
      );
    });
  });

  group('MercatorProjection.worldSize', () {
    test('is one tile at zoom 0', () {
      expect(MercatorProjection.worldSize(0), MercatorProjection.tileSize);
    });

    test('doubles per zoom level', () {
      expect(MercatorProjection.worldSize(3), 512 * 8);
    });
  });
}
