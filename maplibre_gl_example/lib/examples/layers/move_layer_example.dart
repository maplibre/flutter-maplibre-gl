import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating the [MapLibreMapController.moveLayer] API by
/// letting the user drag-reorder a stack of overlapping, semi-transparent
/// circle layers. Reordering is implemented as a single atomic native
/// operation, so it does not flicker or lose any paint/layout properties.
class MoveLayerExample extends ExamplePage {
  const MoveLayerExample({super.key})
    : super(
        const Icon(Icons.reorder),
        'Move Layer',
        category: ExampleCategory.layers,
      );

  @override
  Widget build(BuildContext context) => const _MoveLayerExampleBody();
}

class _DemoLayer {
  final String id;
  final String label;
  final Color color;
  final LatLng center;

  const _DemoLayer({
    required this.id,
    required this.label,
    required this.color,
    required this.center,
  });
}

class _MoveLayerExampleBody extends StatefulWidget {
  const _MoveLayerExampleBody();

  @override
  State<_MoveLayerExampleBody> createState() => _MoveLayerExampleBodyState();
}

class _MoveLayerExampleBodyState extends State<_MoveLayerExampleBody> {
  MapLibreMapController? _controller;
  bool _layersCreated = false;

  // Defined bottom-to-top: each layer is added on top of the previous one,
  // so "blue" starts as the topmost layer by default.
  static final List<_DemoLayer> _demoLayers = [
    const _DemoLayer(
      id: 'move-layer-red',
      label: 'Red',
      color: Colors.red,
      center: ExampleConstants.sydneyCenter,
    ),
    _DemoLayer(
      id: 'move-layer-green',
      label: 'Green',
      color: Colors.green,
      center: LatLng(
        ExampleConstants.sydneyCenter.latitude + 0.01,
        ExampleConstants.sydneyCenter.longitude + 0.015,
      ),
    ),
    _DemoLayer(
      id: 'move-layer-blue',
      label: 'Blue',
      color: Colors.blue,
      center: LatLng(
        ExampleConstants.sydneyCenter.latitude - 0.01,
        ExampleConstants.sydneyCenter.longitude + 0.015,
      ),
    ),
  ];

  // Current stacking order, topmost layer first. Kept in sync with the
  // native layer stack via [MapLibreMapController.moveLayer].
  final List<String> _layerOrder =
      _demoLayers.reversed.map((l) => l.id).toList();

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    if (_controller == null) return;

    for (final layer in _demoLayers) {
      await _controller!.addGeoJsonSource(layer.id, {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [layer.center.longitude, layer.center.latitude],
        },
        'properties': {},
      });

      await _controller!.addLayer(
        layer.id,
        layer.id,
        CircleLayerProperties(
          circleRadius: 70,
          circleColor: layer.color.toHexStringRGB(),
          circleOpacity: 0.75,
          circleStrokeWidth: 2,
          circleStrokeColor: '#000000',
        ),
      );
    }

    setState(() => _layersCreated = true);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final controller = _controller;
    if (controller == null) return;

    late final String movedId;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      movedId = _layerOrder.removeAt(oldIndex);
      _layerOrder.insert(newIndex, movedId);
    });

    await controller.moveLayer(
      movedId,
      belowLayerId: newIndex > 0 ? _layerOrder[newIndex - 1] : null,
    );
  }

  _DemoLayer _layerFor(String id) => _demoLayers.firstWhere((l) => l.id == id);

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 11,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        styleString: ExampleConstants.demoMapStyle,
      ),
      controls: [_buildControls()],
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoCard(
          title: 'Drag to reorder layers',
          subtitle:
              'Dragging calls moveLayer(), which removes and re-inserts the '
              'existing native layer object in a single call — no flicker, '
              'no lost paint/layout properties.',
          icon: Icons.info_outline,
        ),
        const SizedBox(height: 8),
        if (!_layersCreated)
          const Padding(
            padding: EdgeInsets.all(ExampleConstants.paddingStandard),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Card(
            margin: const EdgeInsets.all(ExampleConstants.paddingStandard),
            clipBehavior: Clip.antiAlias,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _layerOrder.length,
              // `onReorder` is deprecated after Flutter 3.41 in favour of
              // `onReorderItem`, but the latter is only available from
              // Flutter 3.44. Keep `onReorder` to stay compatible with the
              // minimum supported Flutter version.
              // ignore: deprecated_member_use
              onReorder:
                  (oldIndex, newIndex) =>
                      unawaited(_onReorder(oldIndex, newIndex)),
              itemBuilder: (context, index) {
                final layerId = _layerOrder[index];
                final layer = _layerFor(layerId);
                return ListTile(
                  key: ValueKey(layerId),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(layer.label),
                  subtitle: Text(
                    index == 0
                        ? 'Topmost'
                        : 'Below "${_layerFor(_layerOrder[index - 1]).label}"',
                  ),
                  trailing: CircleAvatar(backgroundColor: layer.color),
                );
              },
            ),
          ),
      ],
    );
  }
}
