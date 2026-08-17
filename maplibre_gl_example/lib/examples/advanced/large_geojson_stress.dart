import 'dart:async' show unawaited;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Stress test for adding very large GeoJSON sources (#366).
///
/// Encoding a large GeoJSON payload used to run `jsonEncode` synchronously on
/// the main isolate, freezing the UI for a noticeable time. The spinner below
/// keeps animating via [AnimationController]; if the main thread is blocked the
/// spinner visibly stutters. With the encode moved off the main isolate for
/// large payloads it should keep spinning smoothly while the source loads.
class LargeGeojsonStressPage extends ExamplePage {
  const LargeGeojsonStressPage({super.key})
    : super(
        const Icon(Icons.speed),
        'Large GeoJSON (stress)',
        category: ExampleCategory.advanced,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _LargeGeojsonStressBody();
}

class _LargeGeojsonStressBody extends StatefulWidget {
  const _LargeGeojsonStressBody();

  @override
  State<_LargeGeojsonStressBody> createState() =>
      _LargeGeojsonStressBodyState();
}

class _LargeGeojsonStressBodyState extends State<_LargeGeojsonStressBody>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? _controller;
  late final AnimationController _spinner;

  static const _sourceId = 'stress_source';
  static const _layerId = 'stress_layer';

  bool _busy = false;
  int? _lastPointCount;
  Duration? _lastDuration;

  @override
  void initState() {
    super.initState();
    // A continuously running animation: stutter = the UI thread was blocked.
    _spinner = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    unawaited(_spinner.repeat());
  }

  @override
  void dispose() {
    _spinner.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    // Start small so the layer exists; the buttons replace the data with
    // progressively larger payloads.
    await _controller!.addGeoJsonSource(_sourceId, _buildLine(100));
    await _controller!.addLineLayer(
      _sourceId,
      _layerId,
      const LineLayerProperties(lineColor: '#E74C3C', lineWidth: 2),
    );
    setState(() => _lastPointCount = 100);
  }

  /// Builds a FeatureCollection with a single LineString of [pointCount]
  /// points, the shape that triggers #366.
  Map<String, dynamic> _buildLine(int pointCount) {
    final random = Random(42);
    final coordinates = <List<double>>[];
    var lng = 151.0;
    var lat = -33.9;
    for (var i = 0; i < pointCount; i++) {
      lng += (random.nextDouble() - 0.5) * 0.001;
      lat += (random.nextDouble() - 0.5) * 0.001;
      coordinates.add([lng, lat]);
    }
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
        },
      ],
    };
  }

  Future<void> _loadLine(int pointCount) async {
    final controller = _controller;
    if (controller == null || _busy) return;

    setState(() => _busy = true);
    final geojson = _buildLine(pointCount);

    final stopwatch = Stopwatch()..start();
    try {
      await controller.setGeoJsonSource(_sourceId, geojson);
      stopwatch.stop();
      setState(() {
        _lastPointCount = pointCount;
        _lastDuration = stopwatch.elapsed;
      });
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading source: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 10,
        ),
      ),
      controls:
          _controller == null
              ? const []
              : [
                ControlGroup(
                  title: 'Smoothness indicator',
                  children: [
                    ListTile(
                      leading: RotationTransition(
                        turns: _spinner,
                        child: const Icon(Icons.sync, size: 32),
                      ),
                      title: const Text('This should never stutter'),
                      subtitle: Text(
                        _busy
                            ? 'Loading…'
                            : _lastPointCount == null
                            ? 'Idle'
                            : 'Last: $_lastPointCount points'
                                '${_lastDuration != null ? ' in '
                                        '${_lastDuration!.inMilliseconds} ms' : ''}',
                      ),
                    ),
                  ],
                ),
                ControlGroup(
                  title: 'Load a LineString',
                  children: [
                    ExampleButton(
                      label: '1k points',
                      onPressed: _busy ? null : () => _loadLine(1000),
                    ),
                    ExampleButton(
                      label: '10k points',
                      onPressed: _busy ? null : () => _loadLine(10000),
                    ),
                    ExampleButton(
                      label: '40k points',
                      onPressed: _busy ? null : () => _loadLine(40000),
                    ),
                    ExampleButton(
                      label: '100k points',
                      onPressed: _busy ? null : () => _loadLine(100000),
                    ),
                  ],
                ),
              ],
    );
  }
}
