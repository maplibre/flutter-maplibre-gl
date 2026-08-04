// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl_platform_interface.dart';

/// Selects which source feeds location updates into the map's user-location
/// component (the "puck").
///
/// Pass an instance to `MapLibreMap.locationSource`. It only has an effect when
/// `myLocationEnabled` is set to `true`.
///
/// These classes are pure markers: they carry no serialization logic. A
/// `switch` expression at the platform-channel boundary converts the source to
/// a string token, and the native side decides what each token means (engine
/// vs. app-provided updates).
///
/// See also:
///  * [PlatformLocationSource], the default native location engine.
///  * [ManualLocationSource], app-provided locations pushed via
///    `MapLibreMapController.updateManualLocation`.
@immutable
sealed class LocationSource {
  const LocationSource();
}

/// The default location source: the platform's native location engine drives
/// the user-location component.
///
/// This requires the usual runtime location permissions on Android and iOS.
class PlatformLocationSource extends LocationSource {
  /// Creates a marker selecting the platform's native location engine.
  const PlatformLocationSource();
}

/// An app-provided location source.
///
/// The native location engine is disabled and the app feeds location updates
/// into the existing user-location component by calling
/// `MapLibreMapController.updateManualLocation`. Accuracy ring, tracking modes,
/// and `onUserLocationUpdated` keep working.
///
/// No location permission is required in this mode, since the SDK does not
/// query the device's location.
///
/// Supported on Android, iOS and web. On Android and iOS the pushed updates
/// drive the SDK's native user-location component. On web there is no such
/// component to feed, so the plugin draws the puck itself (a native-styled dot
/// + accuracy circle + bearing arrow) using map markers (this reuses
/// MapLibre GL JS' user-location styles from `maplibre-gl.css`, which the
/// plugin loads together with the library).
class ManualLocationSource extends LocationSource {
  /// Creates a marker selecting the app-provided location source.
  const ManualLocationSource();
}
