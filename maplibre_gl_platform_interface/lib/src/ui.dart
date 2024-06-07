// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl_platform_interface.dart';

/// The camera mode, which determines how the map camera will track the rendered location.
enum MyLocationTrackingMode {
  none,
  tracking,
  trackingCompass,
  trackingGps,
}

/// Specifies if and how the user's heading/bearing is rendered in the user location indicator.
enum MyLocationRenderMode {
  /// Do not show the user's heading/bearing.
  normal,

  /// Show the user's heading/bearing as determined by the device's compass. On iOS, this causes the user's location to be shown on the map.
  compass,

  /// Show the user's heading/bearing as determined by the device's GPS sensor. Not supported on iOS.
  gps,
}

/// Compass View Position
enum CompassViewPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Attribution Button Position
enum AttributionButtonPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Bounds for the map camera target.
/// Used with [_MapLibreMapOptions] to wrap a [LatLngBounds] value. This allows
/// distinguishing between specifying an unbounded target (null `LatLngBounds`)
/// from not specifying anything (null `CameraTargetBounds`).
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraTargetBounds &&
          runtimeType == other.runtimeType &&
          bounds == other.bounds;

  @override
  int get hashCode => bounds.hashCode;

  @override
  String toString() {
    return 'CameraTargetBounds(bounds: $bounds)';
  }
}

/// Preferred bounds for map camera zoom level.
/// Used with [_MapLibreMapOptions] to wrap min and max zoom. This allows
/// distinguishing between specifying unbounded zooming (null [minZoom] and
/// [maxZoom]) from not specifying anything (null [MinMaxZoomPreference]).
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinMaxZoomPreference &&
          runtimeType == other.runtimeType &&
          minZoom == other.minZoom &&
          maxZoom == other.maxZoom;

  @override
  int get hashCode => Object.hash(minZoom, maxZoom);

  @override
  String toString() {
    return 'MinMaxZoomPreference(minZoom: $minZoom, maxZoom: $maxZoom)';
  }
}
