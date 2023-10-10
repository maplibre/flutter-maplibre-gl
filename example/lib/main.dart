// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:maplibre_gl_example/attribution.dart';
import 'package:maplibre_gl_example/get_map_informations.dart';
import 'package:maplibre_gl_example/given_bounds.dart';
import 'package:maplibre_gl_example/localized_map.dart';
import 'package:maplibre_gl_example/no_location_permission_page.dart';

import 'animate_camera.dart';
import 'annotation_order_maps.dart';
import 'full_map.dart';
import 'line.dart';
import 'local_style.dart';
import 'map_ui.dart';
import 'move_camera.dart';
import 'click_annotations.dart';
import 'page.dart';
import 'place_circle.dart';
import 'place_source.dart';
import 'place_symbol.dart';
import 'place_fill.dart';
import 'scrolling_map.dart';
import 'offline_regions.dart';
import 'custom_marker.dart';
import 'place_batch.dart';
import 'layer.dart';
import 'sources.dart';

import 'package:maplibre_gl/maplibre_gl.dart';

final List<ExamplePage> _allPages = <ExamplePage>[
  const MapUiPage(),
  const FullMapPage(),
  const LocalizedMapPage(),
  const AnimateCameraPage(),
  const MoveCameraPage(),
  const PlaceSymbolPage(),
  const PlaceSourcePage(),
  const LinePage(),
  const LocalStylePage(),
  const LayerPage(),
  const PlaceCirclePage(),
  const PlaceFillPage(),
  const ScrollingMapPage(),
  const OfflineRegionsPage(),
  const AnnotationOrderPage(),
  const CustomMarkerPage(),
  const BatchAddPage(),
  const ClickAnnotationPage(),
  const Sources(),
  const GivenBoundsPage(),
  const GetMapInfoPage(),
  const NoLocationPermissionPage(),
  const AttributionPage(),
];

class MapsDemo extends StatefulWidget {
  const MapsDemo({super.key});

  @override
  State<MapsDemo> createState() => _MapsDemoState();
}

class _MapsDemoState extends State<MapsDemo> {
  /// Determine the android version of the phone and turn off HybridComposition
  /// on older sdk versions to improve performance for these
  ///
  /// !!! Hybrid composition is currently broken do no use !!!
  Future<void> initHybridComposition() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      if (sdkVersion >= 29) {
        MaplibreMap.useHybridComposition = true;
      } else {
        MaplibreMap.useHybridComposition = false;
      }
    }
  }

  void _pushPage(BuildContext context, ExamplePage page) async {
    if (!kIsWeb && page.needsLocationPermission) {
      final location = Location();
      final hasPermissions = await location.hasPermission();
      if (hasPermissions != PermissionStatus.granted) {
        await location.requestPermission();
      }
    }
    if (!mounted) return;

    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
              appBar: AppBar(title: Text(page.title)),
              body: page,
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maplibre examples')),
      body: ListView.builder(
        itemCount: _allPages.length + 1,
        itemBuilder: (_, int index) => index == _allPages.length
            ? const AboutListTile(
                applicationName: "flutter-maplibre-gl example",
              )
            : ListTile(
                leading: _allPages[index].leading,
                title: Text(_allPages[index].title),
                onTap: () => _pushPage(context, _allPages[index]),
              ),
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(home: MapsDemo()));
}
