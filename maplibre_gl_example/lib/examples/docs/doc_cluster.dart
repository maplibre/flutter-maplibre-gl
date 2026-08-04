import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocClusterExample extends ExamplePage {
  const DocClusterExample({super.key})
    : super(
        const Icon(Icons.bubble_chart),
        'Doc Cluster',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocClusterBody();
}

class _DocClusterBody extends StatefulWidget {
  const _DocClusterBody();

  @override
  State<_DocClusterBody> createState() => _DocClusterBodyState();
}

class _DocClusterBodyState extends State<_DocClusterBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'cluster-source';
  static const _clusterCircleId = 'cluster-circles';
  static const _clusterCountId = 'cluster-count';
  static const _unclusteredId = 'unclustered-point';

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    final rng = Random(42);
    final features = List.generate(200, (i) {
      final lat = 48.8566 + (rng.nextDouble() - 0.5) * 8.0;
      final lng = 2.3522 + (rng.nextDouble() - 0.5) * 12.0;
      return {
        'type': 'Feature',
        'properties': {'id': i},
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
      };
    });

    // Pass the data inline when creating the source. A geojson source requires
    // its "data" property up front: on web (maplibre-gl-js) an empty addSource
    // followed by setGeoJsonSource fails validation with
    // 'missing required property "data"', so the dependent layers never attach.
    await ctrl.addSource(
      _sourceId,
      GeojsonSourceProperties(
        data: {'type': 'FeatureCollection', 'features': features},
        cluster: true,
        clusterMaxZoom: 14,
        clusterRadius: 50,
      ),
    );

    await ctrl.addCircleLayer(
      _sourceId,
      _clusterCircleId,
      const CircleLayerProperties(
        circleRadius: [
          Expressions.step,
          [Expressions.get, 'point_count'],
          18,
          10,
          24,
          50,
          32,
          100,
          42,
        ],
        circleColor: [
          Expressions.step,
          [Expressions.get, 'point_count'],
          '#51bbd6',
          10,
          '#f1f075',
          50,
          '#f28cb1',
          100,
          '#E74C3C',
        ],
        circleOpacity: 0.85,
        circleStrokeWidth: 2,
        circleStrokeColor: '#ffffff',
      ),
      filter: ['has', 'point_count'],
    );

    await ctrl.addSymbolLayer(
      _sourceId,
      _clusterCountId,
      const SymbolLayerProperties(
        textField: [Expressions.get, 'point_count_abbreviated'],
        textSize: 13,
        textColor: '#1a1a2e',
        textAllowOverlap: true,
      ),
      filter: ['has', 'point_count'],
    );

    await ctrl.addCircleLayer(
      _sourceId,
      _unclusteredId,
      const CircleLayerProperties(
        circleRadius: 5,
        circleColor: '#296CA8',
        circleStrokeWidth: 1.5,
        circleStrokeColor: '#ffffff',
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
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
          target: LatLng(49.0, 3.0),
          zoom: 4.0,
        ),
      ),
    );
  }
}
