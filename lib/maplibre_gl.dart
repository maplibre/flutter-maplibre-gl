// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library maplibre_gl;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

export 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show
        LatLng,
        LatLngBounds,
        LatLngQuad,
        CameraPosition,
        UserLocation,
        UserHeading,
        CameraUpdate,
        ArgumentCallbacks,
        Symbol,
        SymbolOptions,
        CameraTargetBounds,
        MinMaxZoomPreference,
        MyLocationTrackingMode,
        MyLocationRenderMode,
        CompassViewPosition,
        AttributionButtonPosition,
        Annotation,
        Circle,
        CircleOptions,
        Line,
        LineOptions,
        Fill,
        FillOptions,
        SourceProperties,
        RasterSourceProperties,
        VectorSourceProperties,
        RasterDemSourceProperties,
        GeojsonSourceProperties,
        VideoSourceProperties,
        ImageSourceProperties,
        MapLibreGlPlatform,
        MethodChannelMaplibreGl,
        OnPlatformViewCreatedCallback;

part 'src/controller.dart';

part 'src/mapbox_map.dart';

part 'src/global.dart';

part 'src/offline_region.dart';

part 'src/download_region_status.dart';

part 'src/layer_expressions.dart';

part 'src/layer_properties.dart';

part 'src/color_tools.dart';

part 'src/annotation_manager.dart';

part 'src/util.dart';
