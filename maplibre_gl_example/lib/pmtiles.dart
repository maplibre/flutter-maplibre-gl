import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/page.dart';

const _nullIsland = CameraPosition(target: LatLng(0, 0), zoom: 4.0);

class PMTilesPage extends ExamplePage {
  const PMTilesPage({super.key})
      : super(const Icon(Icons.map), 'PMTiles example');

  @override
  Widget build(BuildContext context) {
    return const PMTilesMap();
  }
}

class PMTilesMap extends StatefulWidget {
  const PMTilesMap({super.key});

  @override
  State createState() => PMTilesMapState();
}

class PMTilesMapState extends State<PMTilesMap> {
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
        onMapCreated: mapController.complete,
        initialCameraPosition: _nullIsland,
        onStyleLoadedCallback: () => setState(() => canInteractWithMap = true),
        styleString: 'assets/pmtiles_style.json',
      ),
    );
  }

  void _moveCameraToNullIsland() => mapController.future.then(
        (c) => c.animateCamera(CameraUpdate.newCameraPosition(_nullIsland)),
      );
}
