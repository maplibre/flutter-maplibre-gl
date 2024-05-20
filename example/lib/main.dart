// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/attribution.dart';
import 'package:maplibre_gl_example/get_map_informations.dart';
import 'package:maplibre_gl_example/given_bounds.dart';
import 'package:maplibre_gl_example/localized_map.dart';
import 'package:maplibre_gl_example/no_location_permission_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'animate_camera.dart';
import 'annotation_order_maps.dart';
import 'click_annotations.dart';
import 'custom_marker.dart';
import 'full_map.dart';
import 'layer.dart';
import 'line.dart';
import 'local_style.dart';
import 'map_ui.dart';
import 'move_camera.dart';
import 'offline_regions.dart';
import 'page.dart';
import 'place_batch.dart';
import 'place_circle.dart';
import 'place_fill.dart';
import 'place_source.dart';
import 'place_symbol.dart';
import 'scrolling_map.dart';
import 'sources.dart';

final List<ExamplePage> _generalPages = <ExamplePage>[
  const MapUiPage(),
  const FullMapPage(),
  const LocalizedMapPage(),
  const AnimateCameraPage(),
  const MoveCameraPage(),
  const LocalStylePage(),
  const ScrollingMapPage(),
  const OfflineRegionsPage(),
  const GivenBoundsPage(),
  const GetMapInfoPage(),
  const NoLocationPermissionPage(),
];

final List<ExamplePage> _featurePages = <ExamplePage>[
  const PlaceSymbolPage(),
  const PlaceSourcePage(),
  const LinePage(),
  const LayerPage(),
  const PlaceCirclePage(),
  const PlaceFillPage(),
  const BatchAddPage(),
  const AnnotationOrderPage(),
  const CustomMarkerPage(),
  const ClickAnnotationPage(),
  const Sources(),
  const AttributionPage(),
];

class MapLibreDemo extends StatefulWidget {
  const MapLibreDemo({super.key});

  @override
  State<MapLibreDemo> createState() => _MapLibreDemoState();
}

class _MapLibreDemoState extends State<MapLibreDemo> {
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
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(page.title)),
          body: page,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 300,
      childAspectRatio: 3,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('MapLibre Example App')),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: ListSectionTitle('General')),
          SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: _generalPages.length,
            itemBuilder: (_, int index) => ListTile(
              leading: _generalPages[index].leading,
              title: Text(_generalPages[index].title),
              onTap: () => _pushPage(context, _generalPages[index]),
            ),
          ),
          const SliverToBoxAdapter(child: ListSectionTitle('Map Features')),
          SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: _featurePages.length,
            itemBuilder: (_, int index) => ListTile(
              leading: _featurePages[index].leading,
              title: Text(_featurePages[index].title),
              onTap: () => _pushPage(context, _featurePages[index]),
            ),
          ),
          const SliverToBoxAdapter(child: ListSectionTitle('About this App')),
          SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildListDelegate([
              ListTile(
                title: const Text("Show licenses"),
                leading: const Icon(Icons.info_outline),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'MapLibre Example App',
                ),
              ),
              ListTile(
                title: const Text("View on pub.dev"),
                leading: const Icon(Icons.flutter_dash),
                onTap: () =>
                    launchUrlString("https://pub.dev/packages/maplibre-gl"),
              ),
              ListTile(
                title: const Text("View source code"),
                leading: const Icon(Icons.code),
                onTap: () => launchUrlString(
                    "https://github.com/maplibre/flutter-maplibre-gl"),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class ListSectionTitle extends StatelessWidget {
  final String title;

  const ListSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 18, color: Theme.of(context).primaryColor),
      ),
    );
  }
}

void main() {
  const mapLibreBlue = Color(0x00295daa);
  final materialTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: mapLibreBlue,
  );

  runApp(MaterialApp(home: const MapLibreDemo(), theme: materialTheme));
}
