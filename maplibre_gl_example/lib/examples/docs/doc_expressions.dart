import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocExpressionsExample extends ExamplePage {
  const DocExpressionsExample({super.key})
    : super(
        const Icon(Icons.auto_awesome),
        'Doc Expressions',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocExpressionsBody();
}

class _DocExpressionsBody extends StatefulWidget {
  const _DocExpressionsBody();

  @override
  State<_DocExpressionsBody> createState() => _DocExpressionsBodyState();
}

class _DocExpressionsBodyState extends State<_DocExpressionsBody> {
  MapLibreMapController? _controller;
  static const _sourceId = 'countries-source';
  static const _fillLayerId = 'countries-fill';
  static const _labelLayerId = 'countries-labels';

  // Countries with GDP per capita (USD) and continent
  static final List<Map<String, Object>> _countries = [
    {
      'name': 'USA',
      'continent': 'Americas',
      'gdp': 65000,
      'coords': [
        [-100.0, 49.0],
        [100.0, 49.0],
        [-100.0, 25.0],
        [-100.0, 49.0],
      ],
      'center': [-98.0, 38.0],
    },
    {
      'name': 'Germany',
      'continent': 'Europe',
      'gdp': 51000,
      'coords': [
        [6.0, 55.0],
        [15.0, 55.0],
        [15.0, 47.0],
        [6.0, 47.0],
        [6.0, 55.0],
      ],
      'center': [10.5, 51.0],
    },
    {
      'name': 'Brazil',
      'continent': 'Americas',
      'gdp': 8700,
      'coords': [
        [-73.0, 5.0],
        [-35.0, 5.0],
        [-35.0, -33.0],
        [-73.0, -33.0],
        [-73.0, 5.0],
      ],
      'center': [-52.0, -14.0],
    },
    {
      'name': 'Japan',
      'continent': 'Asia',
      'gdp': 42000,
      'coords': [
        [130.0, 45.0],
        [145.0, 45.0],
        [145.0, 31.0],
        [130.0, 31.0],
        [130.0, 45.0],
      ],
      'center': [137.5, 36.0],
    },
    {
      'name': 'Nigeria',
      'continent': 'Africa',
      'gdp': 2200,
      'coords': [
        [3.0, 14.0],
        [15.0, 14.0],
        [15.0, 4.0],
        [3.0, 4.0],
        [3.0, 14.0],
      ],
      'center': [8.5, 9.5],
    },
    {
      'name': 'Australia',
      'continent': 'Oceania',
      'gdp': 55000,
      'coords': [
        [114.0, -22.0],
        [154.0, -22.0],
        [154.0, -39.0],
        [114.0, -39.0],
        [114.0, -22.0],
      ],
      'center': [134.0, -28.0],
    },
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
          _countries
              .map(
                (c) => {
                  'type': 'Feature',
                  'properties': {
                    'name': c['name'],
                    'continent': c['continent'],
                    'gdp': c['gdp'],
                  },
                  'geometry': {
                    'type': 'Polygon',
                    'coordinates': [c['coords']],
                  },
                },
              )
              .toList(),
    });

    // Color by continent using match expression
    await ctrl.addFillLayer(
      _sourceId,
      _fillLayerId,
      const FillLayerProperties(
        fillColor: [
          Expressions.match,
          [Expressions.get, 'continent'],
          'Americas', '#3498DB',
          'Europe', '#2ECC71',
          'Asia', '#E74C3C',
          'Africa', '#F39C12',
          'Oceania', '#9B59B6',
          '#95A5A6', // default
        ],
        fillOpacity: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.get, 'gdp'],
          2000,
          0.25,
          65000,
          0.75,
        ],
        fillOutlineColor: '#ffffff',
      ),
    );

    // Label with name
    await ctrl.addSymbolLayer(
      _sourceId,
      _labelLayerId,
      const SymbolLayerProperties(
        textField: [Expressions.get, 'name'],
        textSize: 12,
        textColor: '#1a1a2e',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.5,
        textAllowOverlap: false,
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
          target: LatLng(15.0, 0.0),
          zoom: 1.2,
        ),
      ),
    );
  }
}
