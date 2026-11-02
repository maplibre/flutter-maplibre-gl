import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating the mesh layer: lit 3D meshes drawn natively in the
/// map's 3D scene. One tree mesh is placed hundreds or thousands of times (one
/// instanced draw call), next to an extruded building that hides the trees
/// behind it.
class MeshLayerExample extends ExamplePage {
  const MeshLayerExample({super.key})
    : super(
        const Icon(Icons.park),
        'Mesh Layer',
        category: ExampleCategory.layers,
      );

  @override
  Widget build(BuildContext context) => const _MeshLayerBody();
}

class _MeshLayerBody extends StatefulWidget {
  const _MeshLayerBody();

  @override
  State<_MeshLayerBody> createState() => _MeshLayerBodyState();
}

class _MeshLayerBodyState extends State<_MeshLayerBody> {
  static const _layerId = 'trees';
  static const _center = LatLng(52.5145, 13.3501); // Tiergarten, Berlin

  MapLibreMapController? _controller;
  int _count = 200;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller!;
    // A block to hide trees behind: the mesh layer shares the extrusions' depth
    await controller.addGeoJsonSource('building', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, Object>{},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [13.3496, 52.5141],
                [13.3506, 52.5141],
                [13.3506, 52.5144],
                [13.3496, 52.5144],
                [13.3496, 52.5141],
              ],
            ],
          },
        },
      ],
    });
    await controller.addFillExtrusionLayer(
      'building',
      'building',
      const FillExtrusionLayerProperties(
        fillExtrusionColor: '#B8B2A7',
        fillExtrusionHeight: 18,
      ),
    );
    await _showTrees();
  }

  Future<void> _showTrees() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if ((await controller.getLayerIds()).contains(_layerId)) {
      await controller.removeLayer(_layerId);
    }
    final random = Random(7);
    // Metres to degrees around the centre
    const metresPerDegree = 111320.0;
    final metresPerDegreeLng =
        metresPerDegree * cos(_center.latitude * pi / 180);
    await controller.addMeshLayer(
      _layerId,
      MeshLayer(
        meshes: [_tree()],
        instances: [
          for (var i = 0; i < _count; i++)
            MeshLayerInstance(
              mesh: 0,
              position: LatLng(
                _center.latitude +
                    (random.nextDouble() - 0.5) * 160 / metresPerDegree,
                _center.longitude +
                    (random.nextDouble() - 0.5) * 240 / metresPerDegreeLng,
              ),
              bearing: random.nextDouble() * 360,
              scale: 0.7 + random.nextDouble() * 0.6,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 17.2,
          tilt: 60,
          bearing: 20,
        ),
      ),
      controls: [
        ControlGroup(
          title: 'Trees',
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 200, label: Text('200')),
                ButtonSegment(value: 2000, label: Text('2,000')),
                ButtonSegment(value: 20000, label: Text('20,000')),
              ],
              selected: {_count},
              onSelectionChanged: (value) {
                setState(() => _count = value.first);
                unawaited(_showTrees());
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// A low-poly tree in metres (x east, y north, z up): a trunk and a cone
MeshLayerMesh _tree() {
  final positions = <double>[];
  final normals = <double>[];
  final colors = <double>[];
  final indices = <int>[];

  void cone({
    required double bottom,
    required double top,
    required double radiusBottom,
    required double radiusTop,
    required List<double> color,
  }) {
    const segments = 12;
    final slope = (radiusBottom - radiusTop) / (top - bottom);
    final first = positions.length ~/ 3;
    for (final (z, radius) in [(bottom, radiusBottom), (top, radiusTop)]) {
      for (var i = 0; i < segments; i++) {
        final angle = 2 * pi * i / segments;
        positions.addAll([radius * cos(angle), radius * sin(angle), z]);
        final length = sqrt(1 + slope * slope);
        normals.addAll([
          cos(angle) / length,
          sin(angle) / length,
          slope / length,
        ]);
        colors.addAll([...color, 1]);
      }
    }
    for (var i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      indices.addAll([
        first + i,
        first + next,
        first + segments + next,
        first + i,
        first + segments + next,
        first + segments + i,
      ]);
    }
  }

  cone(
    bottom: 0,
    top: 2,
    radiusBottom: 0.25,
    radiusTop: 0.2,
    color: [0.45, 0.33, 0.22],
  );
  cone(
    bottom: 1.6,
    top: 7,
    radiusBottom: 2.2,
    radiusTop: 0.05,
    color: [0.25, 0.52, 0.27],
  );

  return MeshLayerMesh(
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    colors: Float32List.fromList(colors),
    indices: Int32List.fromList(indices),
  );
}
