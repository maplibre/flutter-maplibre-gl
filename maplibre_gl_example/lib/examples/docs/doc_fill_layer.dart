import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocFillLayerExample extends ExamplePage {
  const DocFillLayerExample({super.key})
    : super(
        const Icon(Icons.format_color_fill),
        'Doc Fill Layer',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocFillLayerBody();
}

class _DocFillLayerBody extends StatefulWidget {
  const _DocFillLayerBody();

  @override
  State<_DocFillLayerBody> createState() => _DocFillLayerBodyState();
}

class _DocFillLayerBodyState extends State<_DocFillLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'regions-source';
  static const _fillLayerId = 'regions-fill';
  static const _outlineLayerId = 'regions-outline';

  // Approximate bounding polygons for a few European regions
  static final List<Map<String, Object>> _features = [
    {
      'name': 'France',
      'color': '#4A90D9',
      'coordinates': [
        [
          [-4.8, 43.3],
          [8.2, 43.3],
          [8.2, 51.1],
          [-4.8, 51.1],
          [-4.8, 43.3],
        ],
      ],
    },
    {
      'name': 'Germany',
      'color': '#E8A838',
      'coordinates': [
        [
          [6.0, 47.3],
          [15.0, 47.3],
          [15.0, 55.1],
          [6.0, 55.1],
          [6.0, 47.3],
        ],
      ],
    },
    {
      'name': 'Spain',
      'color': '#E84040',
      'coordinates': [
        [
          [-9.3, 36.0],
          [3.3, 36.0],
          [3.3, 43.8],
          [-9.3, 43.8],
          [-9.3, 36.0],
        ],
      ],
    },
    {
      'name': 'Italy',
      'color': '#4CAF50',
      'coordinates': [
        [
          [6.6, 37.9],
          [18.5, 37.9],
          [18.5, 47.1],
          [6.6, 47.1],
          [6.6, 37.9],
        ],
      ],
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
          _features
              .map(
                (f) => {
                  'type': 'Feature',
                  'properties': {
                    'name': f['name'],
                    'color': f['color'],
                  },
                  'geometry': {
                    'type': 'Polygon',
                    'coordinates': f['coordinates'],
                  },
                },
              )
              .toList(),
    });

    await ctrl.addFillLayer(
      _sourceId,
      _fillLayerId,
      const FillLayerProperties(
        fillColor: [Expressions.get, 'color'],
        fillOpacity: 0.35,
      ),
    );

    await ctrl.addLineLayer(
      _sourceId,
      _outlineLayerId,
      const LineLayerProperties(
        lineColor: [Expressions.get, 'color'],
        lineWidth: 2.0,
        lineOpacity: 0.8,
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
          target: LatLng(47.0, 5.0),
          zoom: 3.5,
        ),
      ),
    );
  }
}
