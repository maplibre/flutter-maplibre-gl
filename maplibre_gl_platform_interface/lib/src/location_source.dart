// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl_platform_interface.dart';

/// Selects which source feeds location updates into the map's user-location
/// component (the "puck").
///
/// Pass an instance to `MapLibreMap.locationSource`. `myLocationEnabled`
/// decides whether the puck is shown.
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
/// The native location engine is disabled and the app feeds the puck itself, by
/// calling `MapLibreMapController.updateManualLocation`. The accuracy ring, the
/// tracking modes and `onUserLocationUpdated` keep working, and no location
/// permission is required, since the SDK never queries the device.
///
/// This is the only requirement of `updateManualLocation`: `myLocationEnabled`
/// only shows or hides the puck. While it is off the last location pushed is
/// kept, without `onUserLocationUpdated`, and the puck shows up there when it
/// turns on.
///
/// Works on Android, iOS and web. Web has no native user-location component to
/// feed, so there the plugin draws the puck itself, styled from
/// `maplibre-gl.css`.
class ManualLocationSource extends LocationSource {
  /// Creates a marker selecting the app-provided location source.
  const ManualLocationSource();
}
