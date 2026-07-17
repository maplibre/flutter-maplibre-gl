import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocHeatmapExample extends ExamplePage {
  const DocHeatmapExample({super.key})
    : super(
        const Icon(Icons.whatshot),
        'Doc Heatmap',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocHeatmapBody();
}

class _DocHeatmapBody extends StatefulWidget {
  const _DocHeatmapBody();

  @override
  State<_DocHeatmapBody> createState() => _DocHeatmapBodyState();
}

class _DocHeatmapBodyState extends State<_DocHeatmapBody> {
  MapLibreMapController? _controller;
  static const _sourceId = 'heatmap-source';
  static const _layerId = 'heatmap-layer';

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    final rng = Random(99);
    // Cluster points around major world cities
    final centers = [
      [40.7128, -74.0060], // New York
      [51.5074, -0.1278], // London
      [35.6762, 139.6503], // Tokyo
      [19.0760, 72.8777], // Mumbai
      [-23.5505, -46.6333], // São Paulo
      [31.2304, 121.4737], // Shanghai
    ];

    final features = <Map<String, dynamic>>[];
    for (final center in centers) {
      for (var i = 0; i < 40; i++) {
        final lat = center[0] + (rng.nextDouble() - 0.5) * 4.0;
        final lng = center[1] + (rng.nextDouble() - 0.5) * 4.0;
        final weight = rng.nextDouble();
        features.add({
          'type': 'Feature',
          'properties': {'weight': weight},
          'geometry': {
            'type': 'Point',
            'coordinates': [lng, lat],
          },
        });
      }
    }

    await ctrl.addGeoJsonSource(_sourceId, {
      'type': 'FeatureCollection',
      'features': features,
    });

    await ctrl.addHeatmapLayer(
      _sourceId,
      _layerId,
      const HeatmapLayerProperties(
        heatmapWeight: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.get, 'weight'],
          0,
          0,
          1,
          1,
        ],
        heatmapIntensity: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          0,
          1,
          9,
          3,
        ],
        heatmapColor: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.heatmapDensity],
          0,
          'rgba(33,102,172,0)',
          0.2,
          'rgb(103,169,207)',
          0.4,
          'rgb(209,229,240)',
          0.6,
          'rgb(253,219,199)',
          0.8,
          'rgb(239,138,98)',
          1,
          'rgb(178,24,43)',
        ],
        heatmapRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          0,
          2,
          9,
          20,
        ],
        heatmapOpacity: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          7,
          1,
          9,
          0.7,
        ],
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
          target: LatLng(20.0, 10.0),
          zoom: 1.5,
        ),
      ),
    );
  }
}
