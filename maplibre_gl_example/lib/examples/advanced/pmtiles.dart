import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

const _nullIsland = CameraPosition(target: LatLng(0, 0), zoom: 4.0);

/// Example demonstrating PMTiles vector tiles format
class PMTilesPage extends ExamplePage {
  const PMTilesPage({super.key})
      : super(
          const Icon(Icons.map_outlined),
          'PMTiles',
          category: ExampleCategory.advanced,
        );

  @override
  Widget build(BuildContext context) => const _PMTilesBody();
}

class _PMTilesBody extends StatefulWidget {
  const _PMTilesBody();

  @override
  State<_PMTilesBody> createState() => _PMTilesBodyState();
}

class _PMTilesBodyState extends State<_PMTilesBody> {
  MapLibreMapController? _mapController;
  bool _canInteractWithMap = false;
  bool _canReset = false;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() => _canInteractWithMap = true);
  }

  Future<void> _moveCameraToLondon() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(ExampleConstants.londonCameraPosition),
    );
    setState(() => _canReset = true);
  }

  Future<void> _resetCamera() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_nullIsland),
    );
    setState(() => _canReset = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: 'assets/pmtiles_style.json',
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: _nullIsland,
        logoEnabled: true,
        trackCameraPosition: true,
        compassEnabled: true,
      ),
      floatingActionButton: ExampleButton(
        label: _canReset ? 'Reset camera' : 'Go to London',
        icon: _canReset ? Icons.refresh : Icons.flight_takeoff,
        onPressed: _canInteractWithMap
            ? _canReset
                ? _resetCamera
                : _moveCameraToLondon
            : null,
        style: ExampleButtonStyle.tonal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
