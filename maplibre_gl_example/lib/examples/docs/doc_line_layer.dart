import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocLineLayerExample extends ExamplePage {
  const DocLineLayerExample({super.key})
    : super(
        const Icon(Icons.timeline),
        'Doc Line Layer',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocLineLayerBody();
}

class _DocLineLayerBody extends StatefulWidget {
  const _DocLineLayerBody();

  @override
  State<_DocLineLayerBody> createState() => _DocLineLayerBodyState();
}

class _DocLineLayerBodyState extends State<_DocLineLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'route-source';
  static const _layerId = 'route-layer';

  // Simplified Trans-Siberian Railway route points
  static const _routeCoords = [
    [37.62, 55.75], // Moscow
    [56.85, 53.20], // Kazan
    [60.60, 56.85], // Yekaterinburg
    [73.39, 54.99], // Omsk
    [82.93, 54.98], // Novosibirsk
    [92.79, 56.01], // Krasnoyarsk
    [104.29, 52.29], // Irkutsk
    [107.61, 51.83], // Ulan-Ude
    [113.50, 50.27], // Chita
    [132.04, 43.13], // Vladivostok
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    await ctrl.addGeoJsonSource(_sourceId, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'name': 'Trans-Siberian Railway'},
          'geometry': {
            'type': 'LineString',
            'coordinates': _routeCoords,
          },
        },
      ],
    });

    // Casing (outline)
    await ctrl.addLineLayer(
      _sourceId,
      '$_layerId-casing',
      const LineLayerProperties(
        lineColor: '#1a1a2e',
        lineWidth: 6.0,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    // Main line
    await ctrl.addLineLayer(
      _sourceId,
      _layerId,
      const LineLayerProperties(
        lineColor: '#E74C3C',
        lineWidth: 3.5,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: [2, 1.5],
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
          target: LatLng(55.0, 85.0),
          zoom: 2.8,
        ),
      ),
    );
  }
}
