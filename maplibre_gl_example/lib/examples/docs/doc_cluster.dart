import 'dart:async';
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

  /// What the last cluster tap reported, shown in the banner.
  String? _lastTapMessage;

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

  void _onMapClick(Point<double> point, LatLng coordinates) {
    unawaited(_zoomToClusterAt(point, coordinates));
  }

  /// Zooms to the level at which the tapped cluster splits, rather than
  /// guessing with the current zoom plus a constant.
  Future<void> _zoomToClusterAt(Point<double> point, LatLng coordinates) async {
    final ctrl = _controller;
    if (ctrl == null) return;

    final features = await ctrl.queryRenderedFeatures(
      point,
      [_clusterCircleId],
      null,
    );
    if (features.isEmpty) return;

    final feature = features.first as Map;
    final properties = feature['properties'] as Map?;
    // cluster_id arrives as a num: an int from the native channels, a double
    // from the JS interop on web.
    final clusterId = (properties?['cluster_id'] as num?)?.toInt();
    final pointCount = (properties?['point_count'] as num?)?.toInt() ?? 0;
    if (clusterId == null) return;

    final expansionZoom = await ctrl.getClusterExpansionZoom(
      _sourceId,
      clusterId,
    );
    // The leaves are the original points behind the bubble. Asking for
    // point_count of them reads the whole cluster in one call.
    final leaves = await ctrl.getClusterLeaves(
      _sourceId,
      clusterId,
      limit: pointCount,
    );
    final children = await ctrl.getClusterChildren(_sourceId, clusterId);

    // Centre on the cluster itself and go to exactly the zoom it splits at,
    // like the MapLibre GL JS cluster example. The tap can land well off the
    // centre of a big bubble, which would leave the split half off screen.
    final coordinatesOfCluster = (feature['geometry'] as Map?)?['coordinates'];
    final target =
        coordinatesOfCluster is List && coordinatesOfCluster.length >= 2
            ? LatLng(
              (coordinatesOfCluster[1] as num).toDouble(),
              (coordinatesOfCluster[0] as num).toDouble(),
            )
            : coordinates;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(target, expansionZoom.toDouble()),
      duration: const Duration(milliseconds: 600),
    );

    if (!mounted) return;
    setState(() {
      _lastTapMessage =
          'Cluster $clusterId: $pointCount points, ${children.length} children, '
          'splits at zoom $expansionZoom (${leaves.length} leaves read)';
    });
  }

  static const _initialTarget = LatLng(49.0, 3.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A plain Scaffold rather than MapExampleScaffold, whose map slot takes a
    // MapLibreMap and so cannot hold the banner overlaid on the map.
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: ExampleConstants.demoMapStyle,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            // The cluster circles are an interactive layer, so a tap on one is
            // delivered as a feature tap and onMapClick stays silent by
            // default: exactly the taps this example needs to hear about.
            featureTapsTriggersMapClick: true,
            onMapClick: _onMapClick,
            initialCameraPosition: const CameraPosition(
              target: _initialTarget,
              zoom: 4.0,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      _lastTapMessage ??
                          'Tap a cluster to zoom to where it splits',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
