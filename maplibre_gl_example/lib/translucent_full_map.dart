import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

const _nullIsland = CameraPosition(target: LatLng(0, 0), zoom: 4.0);

/// Example demonstrating a translucent map with content underneath
class TranslucentFullMapPage extends ExamplePage {
  const TranslucentFullMapPage({super.key})
      : super(
          const Icon(Icons.layers),
          'Translucent map',
          category: ExampleCategory.advanced,
        );

  @override
  Widget build(BuildContext context) => const _TranslucentMapBody();
}

class _TranslucentMapBody extends StatefulWidget {
  const _TranslucentMapBody();

  @override
  State<_TranslucentMapBody> createState() => _TranslucentMapBodyState();
}

class _TranslucentMapBodyState extends State<_TranslucentMapBody> {
  MapLibreMapController? _mapController;
  bool _canInteractWithMap = false;
  bool _canReset = false;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() => _canInteractWithMap = true);
  }

  Future<void> _moveCameraToNullIsland() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_nullIsland),
    );
    setState(() => _canReset = true);
  }

  Future<void> _resetCamera() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(ExampleConstants.defaultCameraPosition),
    );
    setState(() => _canReset = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const ColoredBox(
            color: Colors.blue,
            child: Center(
              child: Text(
                'Any widget can be here',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          MapLibreMap(
            styleString: 'assets/translucent_style.json',
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: ExampleConstants.defaultCameraPosition,
            logoEnabled: true,
            trackCameraPosition: true,
            compassEnabled: true,
            // This is a random color, for example purposes.
            foregroundLoadColor: Colors.purple,
            // This sets the map to be translucent.
            translucentTextureSurface: true,
          ),
        ],
      ),
      floatingActionButton: ExampleButton(
        label: _canReset ? 'Reset camera' : 'Go to Null Island',
        icon: _canReset ? Icons.refresh : Icons.flight_takeoff,
        onPressed: _canInteractWithMap
            ? _canReset
                ? _resetCamera
                : _moveCameraToNullIsland
            : null,
        style: ExampleButtonStyle.tonal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
