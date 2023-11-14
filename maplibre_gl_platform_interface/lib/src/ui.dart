// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of maplibre_gl_platform_interface;

class MaplibreStyles {
  /// A very simple MapLibre demo style
  static const String DEMO = "https://demotiles.maplibre.org/style.json";
}

/// The camera mode, which determines how the map camera will track the rendered location.
enum MyLocationTrackingMode {
  None,
  Tracking,
  TrackingCompass,
  TrackingGPS,
}

/// Specifies if and how the user's heading/bearing is rendered in the user location indicator.
enum MyLocationRenderMode {
  /// Do not show the user's heading/bearing.
  NORMAL,

  /// Show the user's heading/bearing as determined by the device's compass. On iOS, this causes the user's location to be shown on the map.
  COMPASS,

  /// Show the user's heading/bearing as determined by the device's GPS sensor. Not supported on iOS.
  GPS,
}

/// Compass View Position
enum CompassViewPosition {
  TopLeft,
  TopRight,
  BottomLeft,
  BottomRight,
}

/// Attribution Button Position
enum AttributionButtonPosition {
  TopLeft,
  TopRight,
  BottomLeft,
  BottomRight,
}

/// Bounds for the map camera target.
// Used with [_MaplibreMapOptions] to wrap a [LatLngBounds] value. This allows
// distinguishing between specifying an unbounded target (null `LatLngBounds`)
// from not specifying anything (null `CameraTargetBounds`).
class CameraTargetBounds {
  /// Creates a camera target bounds with the specified bounding box, or null
  /// to indicate that the camera target is not bounded.
  const CameraTargetBounds(this.bounds);

  /// The geographical bounding box for the map camera target.
  ///
  /// A null value means the camera target is unbounded.
  final LatLngBounds? bounds;

  /// Unbounded camera target.
  static const CameraTargetBounds unbounded = CameraTargetBounds(null);

  dynamic toJson() => <dynamic>[bounds?.toList()];

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (runtimeType != other.runtimeType) return false;
    final CameraTargetBounds typedOther = other;
    return bounds == typedOther.bounds;
  }

  @override
  int get hashCode => bounds.hashCode;

  @override
  String toString() {
    return 'CameraTargetBounds(bounds: $bounds)';
  }
}

/// Preferred bounds for map camera zoom level.
// Used with [_MaplibreMapOptions] to wrap min and max zoom. This allows
// distinguishing between specifying unbounded zooming (null `minZoom` and
// `maxZoom`) from not specifying anything (null `MinMaxZoomPreference`).
class MinMaxZoomPreference {
  const MinMaxZoomPreference(this.minZoom, this.maxZoom)
      : assert(minZoom == null || maxZoom == null || minZoom <= maxZoom);

  /// The preferred minimum zoom level or null, if unbounded from below.
  final double? minZoom;

  /// The preferred maximum zoom level or null, if unbounded from above.
  final double? maxZoom;

  /// Unbounded zooming.
  static const MinMaxZoomPreference unbounded =
      MinMaxZoomPreference(null, null);

  dynamic toJson() => <dynamic>[minZoom, maxZoom];

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (runtimeType != other.runtimeType) return false;
    final MinMaxZoomPreference typedOther = other;
    return minZoom == typedOther.minZoom && maxZoom == typedOther.maxZoom;
  }

  @override
  int get hashCode => Object.hash(minZoom, maxZoom);

  @override
  String toString() {
    return 'MinMaxZoomPreference(minZoom: $minZoom, maxZoom: $maxZoom)';
  }
}
