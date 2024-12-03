part of '../maplibre_gl_platform_interface.dart';

/// iOS is not supported at the moment.
@immutable
class LocationEnginePlatforms {
  /// The properties for the Android platform.
  final LocationEngineAndroidProperties androidPlatform;

  /// If [androidPlatform] is not provided, it defaults to [LocationEngineAndroidProperties.defaultProperties].
  const LocationEnginePlatforms({
    this.androidPlatform = LocationEngineAndroidProperties.defaultProperties,
  });

  static const LocationEnginePlatforms defaultPlatform =
      LocationEnginePlatforms();

  List<int> toList() {
    if (Platform.isAndroid) return androidPlatform.toList();
    return [];
  }
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
