part of '../maplibre_gl_platform_interface.dart';

/// Location engine properties that apply across all platforms.
///
/// Use the platform-specific constructors to only set relevant properties:
/// - [LocationEnginePlatforms.android] — [enableHighAccuracy], [interval], [displacement], [priority]
/// - [LocationEnginePlatforms.iOS] — [enableHighAccuracy], [displacement]
/// - [LocationEnginePlatforms.web] — [enableHighAccuracy], [maximumAge], [timeout]
@immutable
class LocationEnginePlatforms {
  // -- Common --

  /// Whether to use high accuracy (GPS) mode.
  ///
  /// On Android, maps to [LocationPriority.highAccuracy] vs [LocationPriority.balanced].
  /// On iOS, maps to kCLLocationAccuracyBest vs kCLLocationAccuracyHundredMeters.
  /// On web, maps to the browser's PositionOptions.enableHighAccuracy.
  final bool enableHighAccuracy;

  // -- Android --

  /// The interval in milliseconds for location updates. (Android only)
  final int? interval;

  /// The location priority for Android.
  ///
  /// When [enableHighAccuracy] is true, this defaults to [LocationPriority.highAccuracy].
  /// When false, defaults to [LocationPriority.balanced].
  /// Set explicitly to override.
  final LocationPriority? priority;

  // -- Android & iOS --

  /// The minimum displacement in meters for location updates.
  /// On iOS, mapped to CLLocationManager.distanceFilter.
  final int? displacement;

  // -- Web --

  /// Maximum age in milliseconds of a cached position that is acceptable
  /// to return. 0 means the device must return a fresh position. (Web only)
  final int? maximumAge;

  /// Maximum time in milliseconds the device is allowed to take in order
  /// to return a position. 0 means no timeout. (Web only)
  final int? timeout;

  const LocationEnginePlatforms._()
    : enableHighAccuracy = false,
      interval = null,
      displacement = null,
      priority = null,
      maximumAge = null,
      timeout = null;

  /// Android-specific constructor.
  ///
  /// Exposes only properties relevant to the Android location engine:
  /// [enableHighAccuracy], [interval], [displacement], and [priority].
  const LocationEnginePlatforms.android({
    this.enableHighAccuracy = false,
    this.interval = 1000,
    this.displacement = 0,
    this.priority,
  }) : maximumAge = null,
       timeout = null;

  /// iOS-specific constructor.
  ///
  /// Exposes only properties relevant to the iOS CLLocationManager:
  /// [enableHighAccuracy] and [displacement] (mapped to distanceFilter).
  const LocationEnginePlatforms.iOS({
    this.enableHighAccuracy = false,
    this.displacement = 0,
  }) : interval = null,
       priority = null,
       maximumAge = null,
       timeout = null;

  /// Web-specific constructor.
  ///
  /// Exposes only properties relevant to the browser's Geolocation API:
  /// [enableHighAccuracy], [maximumAge], and [timeout].
  const LocationEnginePlatforms.web({
    this.enableHighAccuracy = false,
    this.maximumAge = 0,
    this.timeout = 0,
  }) : interval = null,
       displacement = null,
       priority = null;

  static const LocationEnginePlatforms defaultPlatform =
      LocationEnginePlatforms._();

  /// Resolved priority: explicit [priority] if set, otherwise derived from
  /// [enableHighAccuracy].
  LocationPriority get resolvedPriority =>
      priority ??
      (enableHighAccuracy
          ? LocationPriority.highAccuracy
          : LocationPriority.balanced);

  List<int> toList() {
    if (kIsWeb) {
      return [
        if (enableHighAccuracy) 1 else 0,
        maximumAge ?? 0,
        timeout ?? 0,
      ];
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return [
        interval ?? 1000,
        resolvedPriority.index,
        displacement ?? 0,
      ];
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return [
        if (enableHighAccuracy) 1 else 0,
        displacement ?? 0,
      ];
    }

    // Fallback for unsupported/future platforms: use an empty list to avoid
    // ambiguous payloads that could be misinterpreted as iOS-style data.
    return [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationEnginePlatforms &&
          runtimeType == other.runtimeType &&
          enableHighAccuracy == other.enableHighAccuracy &&
          interval == other.interval &&
          displacement == other.displacement &&
          priority == other.priority &&
          maximumAge == other.maximumAge &&
          timeout == other.timeout);

  @override
  int get hashCode => Object.hash(
    enableHighAccuracy,
    interval,
    displacement,
    priority,
    maximumAge,
    timeout,
  );

  @override
  String toString() {
    final parts = <String>['enableHighAccuracy: $enableHighAccuracy'];
    if (interval != null) parts.add('interval: $interval');
    if (displacement != null) parts.add('displacement: $displacement');
    if (priority != null) parts.add('priority: $priority');
    if (maximumAge != null) parts.add('maximumAge: $maximumAge');
    if (timeout != null) parts.add('timeout: $timeout');
    return 'LocationEnginePlatforms{ ${parts.join(', ')} }';
  }
}

/// An enum representing the priority for location accuracy and power usage.
/// (Android only)
enum LocationPriority {
  /// High accuracy, may consume more power.
  highAccuracy,

  /// Balanced accuracy and power usage.
  balanced,

  /// Low power usage, may be less accurate.
  lowPower,

  /// No power usage, only receive location updates when other clients request them.
  noPower,
}
