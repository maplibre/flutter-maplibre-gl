import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocCircleLayerExample extends ExamplePage {
  const DocCircleLayerExample({super.key})
    : super(
        const Icon(Icons.circle),
        'Doc Circle Layer',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocCircleLayerBody();
}

class _DocCircleLayerBody extends StatefulWidget {
  const _DocCircleLayerBody();

  @override
  State<_DocCircleLayerBody> createState() => _DocCircleLayerBodyState();
}

class _DocCircleLayerBodyState extends State<_DocCircleLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'earthquakes-source';
  static const _layerId = 'earthquakes-layer';

  // Simulated earthquake data with magnitude property
  static const List<Map<String, Object>> _earthquakes = [
    {'lat': 37.7749, 'lng': -122.4194, 'mag': 3.2, 'place': 'San Francisco'},
    {'lat': 34.0522, 'lng': -118.2437, 'mag': 5.1, 'place': 'Los Angeles'},
    {'lat': 47.6062, 'lng': -122.3321, 'mag': 2.8, 'place': 'Seattle'},
    {'lat': 45.5051, 'lng': -122.6750, 'mag': 4.3, 'place': 'Portland'},
    {'lat': 36.7783, 'lng': -119.4179, 'mag': 6.2, 'place': 'Fresno'},
    {'lat': 32.7157, 'lng': -117.1611, 'mag': 3.7, 'place': 'San Diego'},
    {'lat': 38.5816, 'lng': -121.4944, 'mag': 4.9, 'place': 'Sacramento'},
    {'lat': 37.3382, 'lng': -121.8863, 'mag': 2.1, 'place': 'San Jose'},
    {'lat': 33.7701, 'lng': -118.1937, 'mag': 5.5, 'place': 'Long Beach'},
    {'lat': 35.3733, 'lng': -119.0187, 'mag': 3.9, 'place': 'Bakersfield'},
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    await ctrl.addGeoJsonSource(_sourceId, {
      'type': 'FeatureCollection',
      'features':
          _earthquakes
              .map(
                (e) => {
                  'type': 'Feature',
                  'properties': {
                    'magnitude': e['mag'],
                    'place': e['place'],
                  },
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [e['lng'], e['lat']],
                  },
                },
              )
              .toList(),
    });

    await ctrl.addCircleLayer(
      _sourceId,
      _layerId,
      const CircleLayerProperties(
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.get, 'magnitude'],
          2.0,
          6.0,
          4.0,
          14.0,
          6.0,
          28.0,
          8.0,
          50.0,
        ],
        circleColor: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.get, 'magnitude'],
          2.0,
          '#4CAF50',
          4.0,
          '#FF9800',
          6.0,
          '#F44336',
          8.0,
          '#B71C1C',
        ],
        circleOpacity: 0.75,
        circleStrokeWidth: 1.5,
        circleStrokeColor: '#ffffff',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      mapOnly: true,
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: LatLng(37.5, -119.5),
          zoom: 5.0,
        ),
      ),
    );
  }
}
