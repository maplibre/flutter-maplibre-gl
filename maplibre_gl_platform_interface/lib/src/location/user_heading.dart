part of maplibre_gl_platform_interface;

/// Type represents a geomagnetic value, measured in microteslas, relative to a
/// device axis in three dimensional space.
class UserHeading {
  /// Represents the direction in degrees, where 0 degrees is magnetic North.
  /// The direction is referenced from the top of the device regardless of
  /// device orientation as well as the orientation of the user interface.
  final double? magneticHeading;

  /// Represents the direction in degrees, where 0 degrees is true North. The
  /// direction is referenced from the top of the device regardless of device
  /// orientation as well as the orientation of the user interface
  final double? trueHeading;

  /// Represents the maximum deviation of where the magnetic heading may differ
  /// from the actual geomagnetic heading in degrees. A negative value indicates
  /// an invalid heading.
  final double? headingAccuracy;

  /// Returns a raw value for the geomagnetism measured in the x-axis.
  final double? x;

  /// Returns a raw value for the geomagnetism measured in the y-axis.
  final double? y;

  /// Returns a raw value for the geomagnetism measured in the z-axis.
  final double? z;

  /// Returns a timestamp for when the magnetic heading was determined.
  final DateTime timestamp;
  const UserHeading(
      {required this.magneticHeading,
      required this.trueHeading,
      required this.headingAccuracy,
      required this.x,
      required this.y,
      required this.z,
      required this.timestamp});
}
