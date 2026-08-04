import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocCameraExample extends ExamplePage {
  const DocCameraExample({super.key})
    : super(
        const Icon(Icons.videocam),
        'Doc Camera',
        category: ExampleCategory.camera,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocCameraBody();
}

class _DocCameraBody extends StatefulWidget {
  const _DocCameraBody();

  @override
  State<_DocCameraBody> createState() => _DocCameraBodyState();
}

class _DocCameraBodyState extends State<_DocCameraBody> {
  MapLibreMapController? _controller;
  int _currentCity = 0;

  static const List<Map<String, Object>> _cities = [
    {'name': 'Tokyo', 'lat': 35.6762, 'lng': 139.6503, 'zoom': 10.0},
    {'name': 'New York', 'lat': 40.7128, 'lng': -74.0060, 'zoom': 10.0},
    {'name': 'Sydney', 'lat': -33.8688, 'lng': 151.2093, 'zoom': 10.0},
    {'name': 'Cairo', 'lat': 30.0444, 'lng': 31.2357, 'zoom': 10.0},
    {'name': 'Rio', 'lat': -22.9068, 'lng': -43.1729, 'zoom': 10.0},
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _flyToNext() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    _currentCity = (_currentCity + 1) % _cities.length;
    final city = _cities[_currentCity];
    await ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            (city['lat']! as num).toDouble(),
            (city['lng']! as num).toDouble(),
          ),
          zoom: (city['zoom']! as num).toDouble(),
        ),
      ),
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      mapOnly: true,
      controls: const [],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _flyToNext,
        icon: const Icon(Icons.flight_takeoff),
        label: const Text('Fly to next city'),
        backgroundColor: const Color(0xFF296CA8),
        foregroundColor: Colors.white,
      ),
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: LatLng(35.6762, 139.6503),
          zoom: 10.0,
        ),
      ),
    );
  }
}
