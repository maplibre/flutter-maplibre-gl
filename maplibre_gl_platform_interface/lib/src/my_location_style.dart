part of '../maplibre_gl_platform_interface.dart';

/// Colors of the user-location puck shown when `myLocationEnabled` is true.
///
/// Every field is optional: a field left null keeps the platform's own look,
/// so `const MyLocationStyle()` changes nothing. Pass it to
/// `MapLibreMap.myLocationStyle`; it can be changed while the map is shown.
///
/// Only parts of the puck that Android, iOS and web can all restyle are
/// exposed. Where a platform draws a part differently, the field documents it.
@immutable
class MyLocationStyle {
  const MyLocationStyle({
    this.fillColor,
    this.bearingColor,
    this.accuracyColor,
    this.accuracyCircleEnabled = true,
    this.pulseEnabled,
    this.pulseColor,
  });

  /// The color of the location dot.
  ///
  /// On Android it is also the color of the navigation arrow drawn in
  /// [MyLocationRenderMode.gps], and on iOS the color of the heading arrow
  /// drawn in [MyLocationRenderMode.compass]. Android still turns the dot grey
  /// when no fix has arrived for a while, as it does by default.
  final Color? fillColor;

  /// The color of the arrow that points along the user's direction.
  ///
  /// Android: the bearing chevron of [MyLocationRenderMode.compass].
  /// iOS: the arrow puck drawn in [MyLocationTrackingMode.trackingGps].
  /// Web: the bearing arrow of the puck drawn for a [ManualLocationSource],
  /// shown when a fix carries a bearing. The browser geolocation puck draws no
  /// direction, so there it has no effect.
  final Color? bearingColor;

  /// The color of the accuracy circle around the dot.
  ///
  /// Only the red, green and blue channels are used: each platform keeps its
  /// own translucency for the circle (about 15% opacity on Android, 10% on
  /// iOS, 20% on web), so the circle never hides the map. Use
  /// [accuracyCircleEnabled] to hide it.
  final Color? accuracyColor;

  /// Whether the accuracy circle is drawn. Defaults to true.
  ///
  /// On iOS the halo drawn while the device only grants an approximate
  /// location stays visible, since it is the only sign of the position then.
  final bool accuracyCircleEnabled;

  /// Whether the dot sends out a pulse. Null keeps the platform default:
  /// off on Android, on for web and on iOS.
  ///
  /// iOS only draws its pulse while the reported accuracy is 10 meters or
  /// better, whatever this is set to.
  final bool? pulseEnabled;

  /// The color of the pulse. It does not turn the pulse on: on Android, where
  /// the pulse is off by default, set [pulseEnabled] too.
  final Color? pulseColor;

  /// The wire format sent to the platforms. Null fields are left out.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (fillColor != null) 'fillColor': fillColor!.toARGB32(),
      if (bearingColor != null) 'bearingColor': bearingColor!.toARGB32(),
      if (accuracyColor != null) 'accuracyColor': accuracyColor!.toARGB32(),
      'accuracyCircleEnabled': accuracyCircleEnabled,
      if (pulseEnabled != null) 'pulseEnabled': pulseEnabled,
      if (pulseColor != null) 'pulseColor': pulseColor!.toARGB32(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MyLocationStyle &&
      other.fillColor == fillColor &&
      other.bearingColor == bearingColor &&
      other.accuracyColor == accuracyColor &&
      other.accuracyCircleEnabled == accuracyCircleEnabled &&
      other.pulseEnabled == pulseEnabled &&
      other.pulseColor == pulseColor;

  @override
  int get hashCode => Object.hash(
    fillColor,
    bearingColor,
    accuracyColor,
    accuracyCircleEnabled,
    pulseEnabled,
    pulseColor,
  );

  @override
  String toString() =>
      'MyLocationStyle(fillColor: $fillColor, bearingColor: $bearingColor, '
      'accuracyColor: $accuracyColor, '
      'accuracyCircleEnabled: $accuracyCircleEnabled, '
      'pulseEnabled: $pulseEnabled, pulseColor: $pulseColor)';
}
