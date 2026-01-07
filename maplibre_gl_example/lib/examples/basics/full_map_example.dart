import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating basic full-screen map
class FullMapExample extends ExamplePage {
  const FullMapExample({super.key})
      : super(
          const Icon(Icons.map),
          'Full screen map',
          category: ExampleCategory.basics,
        );

  @override
  Widget build(BuildContext context) => const _FullMapBody();
}

class _FullMapBody extends StatefulWidget {
  const _FullMapBody();

  @override
  State<_FullMapBody> createState() => _FullMapBodyState();
}

class _FullMapBodyState extends State<_FullMapBody> {
  MapLibreMapController? _mapController;
  bool _canInteractWithMap = false;
  bool canReset = false;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    setState(() => _canInteractWithMap = true);
  }

  Future<void> _moveCameraToSanFrancisco() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        ExampleConstants.sanFranciscoCameraPosition,
      ),
    );
    setState(() => canReset = true);
  }

  Future<void> _resetCamera() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        ExampleConstants.defaultCameraPosition,
      ),
    );
    setState(() => canReset = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        initialCameraPosition: ExampleConstants.defaultCameraPosition,
        logoEnabled: true,
        trackCameraPosition: true,
        compassEnabled: true,
        myLocationEnabled: true,
      ),
      floatingActionButton: ExampleButton(
        label: canReset ? 'Reset camera' : 'Go to San Francisco',
        icon: canReset ? Icons.refresh : Icons.flight_takeoff,
        onPressed: _canInteractWithMap
            ? canReset
                ? _resetCamera
                : _moveCameraToSanFrancisco
            : null,
        style: ExampleButtonStyle.tonal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
