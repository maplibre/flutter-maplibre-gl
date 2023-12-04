// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package com.mapbox.mapboxgl

import com.mapbox.mapboxsdk.geometry.LatLngBounds

/** Receiver of MapboxMap configuration options.  */
internal interface MapboxMapOptionsSink {
    // todo: dddd replace with CameraPosition.Builder target
    fun setCameraTargetBounds(bounds: LatLngBounds)

    fun setCompassEnabled(compassEnabled: Boolean)

    // TODO: styleString is not actually a part of options. consider moving
    fun setStyleString(styleString: String)

    fun setMinMaxZoomPreference(min: Float?, max: Float?)

    fun setRotateGesturesEnabled(rotateGesturesEnabled: Boolean)

    fun setScrollGesturesEnabled(scrollGesturesEnabled: Boolean)

    fun setTiltGesturesEnabled(tiltGesturesEnabled: Boolean)

    fun setTrackCameraPosition(trackCameraPosition: Boolean)

    fun setZoomGesturesEnabled(zoomGesturesEnabled: Boolean)

    fun setMyLocationEnabled(myLocationEnabled: Boolean)

    fun setMyLocationTrackingMode(myLocationTrackingMode: Int)

    fun setMyLocationRenderMode(myLocationRenderMode: Int)

    fun setLogoViewMargins(x: Int, y: Int)

    fun setCompassGravity(gravity: Int)

    fun setCompassViewMargins(x: Int, y: Int)

    fun setAttributionButtonGravity(gravity: Int)

    fun setAttributionButtonMargins(x: Int, y: Int)
}