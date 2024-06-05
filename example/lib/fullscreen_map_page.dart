import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/main.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';

class FullscreenMapPage extends StatefulWidget {
  const FullscreenMapPage({super.key});

  @override
  State<FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<FullscreenMapPage> {
  MaplibreMapController? mapController;
  var isLight = true;

  _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
  }

  _onStyleLoadedCallback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Style loaded :)"),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      page: ExamplePage.fullscreen,
      // TODO: commented out when cherry-picking https://github.com/flutter-mapbox-gl/maps/pull/775
      // needs different dark and light styles in this repo
      // floatingActionButton: Padding(
      // padding: const EdgeInsets.all(32.0),
      // child: FloatingActionButton(
      // child: Icon(Icons.swap_horiz),
      // onPressed: () => setState(
      // () => isLight = !isLight,
      // ),
      // ),
      // ),
      body: MaplibreMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0)),
        onStyleLoadedCallback: _onStyleLoadedCallback,
      ),
    );
  }
}
