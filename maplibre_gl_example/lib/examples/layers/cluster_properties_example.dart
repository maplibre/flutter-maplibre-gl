import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating GeoJSON cluster properties.
///
/// Uses the USGS earthquakes dataset and aggregates two values across each
/// cluster:
///  * `max_mag` — the maximum magnitude of any earthquake in the cluster,
///    declared with the *simple* operator-string form `["max", ["get", "mag"]]`.
///  * `mag_sum` — the sum of magnitudes in the cluster, declared with the
///    explicit reduce-expression form using `["accumulated"]`.
///
/// Both aggregates are displayed in the cluster label so the effect of
/// clusterProperties is visible on screen.
///
/// Note: on iOS, complex expressions such as `case` used inside a cluster
/// mapExpr can silently break the entire cluster property pipeline (including
/// the built-in `point_count_abbreviated` becoming unavailable). Stick to
/// straightforward numeric map expressions until this is fixed upstream.
class ClusterPropertiesExample extends ExamplePage {
  const ClusterPropertiesExample({super.key})
    : super(
        const Icon(Icons.hub_outlined),
        'Cluster Properties',
        category: ExampleCategory.layers,
      );

  @override
  Widget build(BuildContext context) => const _ClusterPropertiesBody();
}

class _ClusterPropertiesBody extends StatefulWidget {
  const _ClusterPropertiesBody();

  @override
  State<_ClusterPropertiesBody> createState() => _ClusterPropertiesBodyState();
}

class _ClusterPropertiesBodyState extends State<_ClusterPropertiesBody> {
  static const _sourceId = 'earthquakes';

  MapLibreMapController? _controller;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.addSource(
      _sourceId,
      const GeojsonSourceProperties(
        data:
            'https://maplibre.org/maplibre-gl-js/docs/assets/earthquakes.geojson',
        cluster: true,
        clusterRadius: 50,
        clusterMaxZoom: 14,
        clusterProperties: {
          // Simple form: [operator, mapExpr].
          'max_mag': ['max', ['get', 'mag']],
          // Reduce-expression form: [fullReduceExpr, mapExpr].
          'mag_sum': [
            ['+', ['accumulated'], ['get', 'mag_sum']],
            ['get', 'mag'],
          ],
        },
        attribution:
            '<a href="https://maplibre.org">Earthquake data © MapLibre</a>',
      ),
    );

    await controller.addLayer(
      _sourceId,
      'earthquakes-cluster-circles',
      const CircleLayerProperties(
        circleColor: [
          Expressions.step,
          [Expressions.get, 'point_count'],
          '#51bbd6',
          100,
          '#f1f075',
          750,
          '#f28cb1',
        ],
        circleRadius: [
          Expressions.step,
          [Expressions.get, 'point_count'],
          22,
          100,
          30,
          750,
          38,
        ],
      ),
      filter: ['has', 'point_count'],
    );

    // Label shows point count plus both aggregated values. Numeric values are
    // rounded and coerced to string so concat receives only strings, which
    // MapLibre iOS requires strictly.
    await controller.addLayer(
      _sourceId,
      'earthquakes-cluster-labels',
      const SymbolLayerProperties(
        textField: [
          Expressions.concat,
          [Expressions.get, 'point_count_abbreviated'],
          '\nmax ',
          [
            Expressions.toStringExpression,
            // Round max_mag to one decimal: round(v * 10) / 10.
            [
              '/',
              [
                'round',
                ['*', ['get', 'max_mag'], 10],
              ],
              10,
            ],
          ],
          '\nsum ',
          [
            Expressions.toStringExpression,
            ['round', ['get', 'mag_sum']],
          ],
        ],
        textFont: ['Open Sans Semibold'],
        textSize: 11,
      ),
      filter: ['has', 'point_count'],
    );

    await controller.addLayer(
      _sourceId,
      'earthquakes-unclustered',
      const CircleLayerProperties(
        circleColor: '#11b4da',
        circleRadius: 4,
        circleStrokeColor: '#fff',
        circleStrokeWidth: 1,
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: LatLng(33.5, -118.1),
          zoom: 3,
        ),
      ),
    );
  }
}
