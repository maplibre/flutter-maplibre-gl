library maplibre_gl_web;

import 'dart:async';

// FIXED HERE: https://github.com/dart-lang/linter/pull/1985
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html hide Event;

// ignore: unused_import
import 'dart:js';
import 'dart:js_util';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:image/image.dart' hide Point;
import 'package:maplibre_gl_web/src/geo/point.dart' as geoPoint;
import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/geo/lng_lat_bounds.dart';
import 'package:maplibre_gl_web/src/layer_tools.dart';
import 'package:maplibre_gl_web/src/style/sources/geojson_source.dart';
import 'package:maplibre_gl_web/src/ui/camera.dart';
import 'package:maplibre_gl_web/src/ui/control/geolocate_control.dart';
import 'package:maplibre_gl_web/src/ui/control/navigation_control.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/util/evented.dart';

part 'src/convert.dart';

part 'src/mapbox_map_plugin.dart';

part 'src/options_sink.dart';

part 'src/mapbox_web_gl_platform.dart';
