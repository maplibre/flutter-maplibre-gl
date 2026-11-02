import 'dart:math' as math;

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

/// Returns where the camera target [lat], [lng] must go to sit inside
/// [bounds], or null when it is inside already.
///
/// Latitude and longitude are clamped apart, as on Android. Only the target is
/// limited, never zoom, bearing or tilt, so the map can show area outside the
/// bounds. Pure Dart, so it runs in the VM tests.
///
/// The target longitude may sit in another world copy, past +-180. It is
/// clamped by its wrapped value and the world copy is kept, so the camera
/// does not jump a world over. It comes back as a record, as [LatLng] wraps.
///
/// The longitudes are ordered as Android's `LatLngBounds.Builder` orders them,
/// so bounds never cross the antimeridian: a southwest longitude east of the
/// northeast one spans the longitudes between the two.
({double lat, double lng})? clampCameraTarget(
  double lat,
  double lng,
  LatLngBounds bounds,
) {
  final south = bounds.southwest.latitude;
  final north = bounds.northeast.latitude;
  final west = math.min(bounds.southwest.longitude, bounds.northeast.longitude);
  final east = math.max(bounds.southwest.longitude, bounds.northeast.longitude);

  final clampedLat = lat.clamp(south, north);

  final wrapped = _wrapLongitude(lng);
  final world = lng - wrapped;
  final clampedWrapped = wrapped.clamp(west, east);

  if (clampedLat == lat && clampedWrapped == wrapped) return null;
  return (lat: clampedLat, lng: clampedWrapped + world);
}

double _wrapLongitude(double lng) {
  if (lng >= -180 && lng <= 180) return lng;
  return ((lng + 180) % 360 + 360) % 360 - 180;
}
