import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';

const _nullIsland = CameraPosition(target: LatLng(0, 0), zoom: 4.0);

class TranslucentFullMapPage extends ExamplePage {
  const TranslucentFullMapPage({super.key})
      : super(const Icon(Icons.map), 'Translucent full screen map');

  @override
  Widget build(BuildContext context) {
    return const TranslucentFullMap();
  }
}

class TranslucentFullMap extends StatefulWidget {
  const TranslucentFullMap({super.key});

  @override
  State createState() => TranslucentFullMapState();
}

class TranslucentFullMapState extends State<TranslucentFullMap> {
  final Completer<MapLibreMapController> mapController = Completer();
  bool canInteractWithMap = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: canInteractWithMap
          ? FloatingActionButton(
              onPressed: _moveCameraToNullIsland,
              mini: true,
              child: const Icon(Icons.restore),
            )
          : null,
      body: Stack(
        children: [
          const ColoredBox(
            color: Colors.blue,
            child: Center(
              child: Text(
                'Any widget can be here',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          MapLibreMap(
            styleString: _styleString,
            onMapCreated: (controller) => mapController.complete(controller),
            initialCameraPosition: _nullIsland,
            onStyleLoadedCallback: () => setState(
              () => canInteractWithMap = true,
            ),
            // This is a random color, for example purposes.
            foregroundLoadColor: Colors.purple,
            // This sets the map to be translucent.
            translucentTextureSurface: true,
          ),
        ],
      ),
    );
  }

  String get _styleString => 'assets/translucent_style.json';

  void _moveCameraToNullIsland() => mapController.future.then(
      (c) => c.animateCamera(CameraUpdate.newCameraPosition(_nullIsland)));
}
