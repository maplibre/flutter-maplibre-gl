import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/main.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';

class NoLocationPermissionPage extends StatefulWidget {
  const NoLocationPermissionPage({super.key});

  @override
  State<NoLocationPermissionPage> createState() =>
      _NoLocationPermissionPageState();
}

class _NoLocationPermissionPageState extends State<NoLocationPermissionPage> {
  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      page: ExamplePage.noLocationPermission,
      body: MaplibreMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-33.852, 151.211),
          zoom: 11.0,
        ),
        styleString: "assets/osm_style.json",
      ),
    );
  }
}
