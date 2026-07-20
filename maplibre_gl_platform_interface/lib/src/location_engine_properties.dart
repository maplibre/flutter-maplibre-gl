part of '../maplibre_gl_platform_interface.dart';

@immutable
class LocationEnginePlatforms {
  /// The properties for the Android platform.
  final LocationEngineAndroidProperties androidPlatform;

  /// The properties for the iOS platform.
  final LocationEngineIOSProperties iOSPlatform;

  const LocationEnginePlatforms({
    this.androidPlatform = LocationEngineAndroidProperties.defaultProperties,
    this.iOSPlatform = LocationEngineIOSProperties.defaultProperties,
  });

  static const LocationEnginePlatforms defaultPlatform =
      LocationEnginePlatforms();

  List<int> toList() {
    if (kIsWeb) {
      return [];
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidPlatform.toList();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iOSPlatform.toList();
    }
    return [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationEnginePlatforms &&
          androidPlatform == other.androidPlatform &&
          iOSPlatform == other.iOSPlatform);

  @override
  int get hashCode => androidPlatform.hashCode ^ iOSPlatform.hashCode;
}

/// iOS location engine properties.
///
/// When [intervalMs] > 0 the native side pulses GPS: it starts location updates
/// for a short window (~5 s) then stops, repeating every [intervalMs] ms.
/// This dramatically reduces Location Energy between pulses.
///
/// When [intervalMs] == 0 (default), location updates are continuous.
@immutable
class LocationEngineIOSProperties {
  /// Interval in milliseconds between GPS pulse windows.
  /// 0 = continuous (default / current behaviour).
  final int intervalMs;

  const LocationEngineIOSProperties({this.intervalMs = 0});

  static const LocationEngineIOSProperties defaultProperties =
      LocationEngineIOSProperties();

  List<int> toList() => [intervalMs];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationEngineIOSProperties &&
          intervalMs == other.intervalMs);

  @override
  int get hashCode => intervalMs.hashCode;

  @override
  String toString() =>
      'LocationEngineIOSProperties{ intervalMs: $intervalMs }';
}

@immutable
class LocationEngineAndroidProperties {
  /// The interval in milliseconds for location updates.
  final int interval;

  /// The minimum displacement in meters for location updates.
  final int displacement;

  /// [LocationPriority.highAccuracy] only uses native GPS provider
  /// [LocationPriority.balanced] uses a fused provider (network + GPS)-> better quality indoor
  /// [LocationPriority.lowPower] only uses network provider
  /// [LocationPriority.noPower] only receives location updates when another clients request them
  ///
  final LocationPriority priority;

  const LocationEngineAndroidProperties({
    required this.interval,
    required this.displacement,
    required this.priority,
  });

  static const LocationEngineAndroidProperties defaultProperties =
      LocationEngineAndroidProperties(
    interval: 1000,
    displacement: 0,
    priority: LocationPriority.balanced,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationEngineAndroidProperties &&
          runtimeType == other.runtimeType &&
          interval == other.interval &&
          displacement == other.displacement &&
          priority == other.priority);

  @override
  int get hashCode =>
      interval.hashCode ^ displacement.hashCode ^ priority.hashCode;

  @override
  String toString() {
    return 'LocationEngineAndroidProperties{ interval: $interval, displacement: $displacement, priority: $priority }';
  }

  LocationEngineAndroidProperties copyWith({
    int? interval,
    int? displacement,
    LocationPriority? priority,
  }) {
    return LocationEngineAndroidProperties(
      interval: interval ?? this.interval,
      displacement: displacement ?? this.displacement,
      priority: priority ?? this.priority,
    );
  }

  List<int> toList() {
    return [
      interval,
      priority.index,
      displacement,
    ];
  }
}

/// An enum representing the priority for location accuracy and power usage.
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
