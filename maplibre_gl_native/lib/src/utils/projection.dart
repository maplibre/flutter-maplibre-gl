import 'dart:math' as math;

/// Camera limits of the MapLibre Native projection.
///
/// Dart mirror of `mbgl/util/constants.hpp`. These values define camera
/// parity with the Android and iOS backends: they must not drift from
/// upstream, which is why they are named here instead of being spelled out at
/// each use site.
abstract final class MapLimits {
  /// `util::MIN_ZOOM`, also the value that clears a minimum-zoom preference.
  static const double minZoom = 0;

  /// `util::MAX_ZOOM`, also the value that clears a maximum-zoom preference.
  static const double maxZoom = 25.5;

  /// `util::LATITUDE_MAX`: the Web Mercator projection limit, past which a
  /// latitude cannot be projected.
  static const double latitudeMax = 85.051128779806604;

  // Whole-world bounds. Setting these as the camera target bounds is how the
  // reference backends express "unbounded", so it is also how a previously
  // set constraint is cleared.
  static const double worldSouthLatitude = -90;
  static const double worldNorthLatitude = 90;
  static const double worldWestLongitude = -180;
  static const double worldEastLongitude = 180;
}

/// The spherical Mercator projection MapLibre renders in.
///
/// Dart mirror of `mbgl/util/projection.hpp`, needed on the Flutter side for
/// values the C API does not expose yet (see the package README's C API gap
/// list). Delete in favour of the native call once it lands.
abstract final class MercatorProjection {
  /// `util::tileSize_D`: the projection's world tile size at zoom 0, in
  /// logical pixels. The world is `tileSize * 2^zoom` pixels wide, which is
  /// what defines zoom.
  ///
  /// NOT a style source's `tileSize`: that one is configurable per source
  /// (256 is common for raster) and only changes which tiles the renderer
  /// requests, never the projection.
  static const double tileSize = 512;

  /// `util::EARTH_RADIUS_M`.
  static const double earthRadiusMeters = 6378137;

  /// Map width in logical pixels at [zoom]; `Projection::worldSize`.
  static double worldSize(double zoom) =>
      math.pow(2.0, zoom).toDouble() * tileSize;

  /// Ground resolution in meters per logical pixel at [latitude] and [zoom].
  ///
  /// Mirrors `Projection::getMetersPerPixelAtLatitude`, clamps included: a
  /// caller-supplied latitude or zoom outside the projection range must
  /// produce the same number the Android and iOS backends produce.
  static double metersPerPixel(double latitude, double zoom) {
    final clampedZoom = zoom.clamp(MapLimits.minZoom, MapLimits.maxZoom);
    final clampedLatitude = latitude.clamp(
      -MapLimits.latitudeMax,
      MapLimits.latitudeMax,
    );
    return math.cos(clampedLatitude * math.pi / 180) *
        2 *
        math.pi *
        earthRadiusMeters /
        worldSize(clampedZoom);
  }
}
