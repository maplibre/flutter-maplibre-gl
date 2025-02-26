import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';

const _nullIsland = CameraPosition(target: LatLng(0, 0), zoom: 4.0);

class FullMapPage extends ExamplePage {
  const FullMapPage({super.key})
      : super(const Icon(Icons.map), 'Full screen map');

  @override
  Widget build(BuildContext context) {
    return const FullMap();
  }
}

class FullMap extends StatefulWidget {
  const FullMap({super.key});

  @override
  State createState() => FullMapState();
}

class FullMapState extends State<FullMap> {
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
      body: MapLibreMap(
        onMapCreated: (controller) => mapController.complete(controller),
        initialCameraPosition: _nullIsland,
        onStyleLoadedCallback: () => setState(() => canInteractWithMap = true),
      ),
    );
  }

  void _moveCameraToNullIsland() => mapController.future.then(
      (c) => c.animateCamera(CameraUpdate.newCameraPosition(_nullIsland)));
}
