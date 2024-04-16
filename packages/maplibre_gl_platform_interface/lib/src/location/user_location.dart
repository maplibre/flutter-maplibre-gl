part of maplibre_gl_platform_interface;

/// User's observed location
class UserLocation {
  /// User's position in latitude and longitude
  final LatLng position;

  /// User's altitude in meters
  final double? altitude;

  /// Direction user is traveling, measured in degrees
  final double? bearing;

  /// User's speed in meters per second
  final double? speed;

  /// The radius of uncertainty for the location, measured in meters
  final double? horizontalAccuracy;

  /// Accuracy of the altitude measurement, in meters
  final double? verticalAccuracy;

  /// Time the user's location was observed
  final DateTime timestamp;

  /// The heading of the user location, null if not available.
  final UserHeading? heading;

  const UserLocation(
      {required this.position,
      required this.altitude,
      required this.bearing,
      required this.speed,
      required this.horizontalAccuracy,
      required this.verticalAccuracy,
      required this.timestamp,
      required this.heading});
}
