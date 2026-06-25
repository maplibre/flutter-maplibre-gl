import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocGeoJsonSourceExample extends ExamplePage {
  const DocGeoJsonSourceExample({super.key})
    : super(
        const Icon(Icons.data_object),
        'Doc GeoJSON Source',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocGeoJsonSourceBody();
}

class _DocGeoJsonSourceBody extends StatefulWidget {
  const _DocGeoJsonSourceBody();

  @override
  State<_DocGeoJsonSourceBody> createState() => _DocGeoJsonSourceBodyState();
}

class _DocGeoJsonSourceBodyState extends State<_DocGeoJsonSourceBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'capitals-source';
  static const _circleLayerId = 'capitals-circles';
  static const _labelLayerId = 'capitals-labels';

  static const List<Map<String, Object>> _capitals = [
    {'name': 'Washington D.C.', 'lat': 38.9072, 'lng': -77.0369, 'pop': 700000},
    {'name': 'Ottawa', 'lat': 45.4215, 'lng': -75.6972, 'pop': 1000000},
    {'name': 'Mexico City', 'lat': 19.4326, 'lng': -99.1332, 'pop': 9000000},
    {'name': 'Brasilia', 'lat': -15.7801, 'lng': -47.9292, 'pop': 3000000},
    {'name': 'Buenos Aires', 'lat': -34.6037, 'lng': -58.3816, 'pop': 3000000},
    {'name': 'Lima', 'lat': -12.0464, 'lng': -77.0428, 'pop': 10000000},
    {'name': 'Bogota', 'lat': 4.7110, 'lng': -74.0721, 'pop': 8000000},
    {'name': 'Santiago', 'lat': -33.4489, 'lng': -70.6693, 'pop': 6000000},
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    // Inline GeoJSON FeatureCollection
    await ctrl.addGeoJsonSource(_sourceId, {
      'type': 'FeatureCollection',
      'features':
          _capitals
              .map(
                (c) => {
                  'type': 'Feature',
                  'properties': {
                    'name': c['name'],
                    'population': c['pop'],
                  },
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [c['lng'], c['lat']],
                  },
                },
              )
              .toList(),
    });

    await ctrl.addCircleLayer(
      _sourceId,
      _circleLayerId,
      const CircleLayerProperties(
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.get, 'population'],
          700000,
          6.0,
          10000000,
          20.0,
        ],
        circleColor: '#296CA8',
        circleOpacity: 0.8,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 1.5,
      ),
    );

    await ctrl.addSymbolLayer(
      _sourceId,
      _labelLayerId,
      const SymbolLayerProperties(
        textField: [Expressions.get, 'name'],
        textSize: 11,
        textColor: '#1a1a2e',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.5,
        textOffset: [0, 1.6],
        textAnchor: 'top',
        textAllowOverlap: false,
        textIgnorePlacement: false,
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
          target: LatLng(5.0, -65.0),
          zoom: 2.5,
        ),
      ),
    );
  }
}
