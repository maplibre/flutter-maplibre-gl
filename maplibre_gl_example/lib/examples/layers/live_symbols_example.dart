import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Symbols that update every second, with the three ways to handle
/// placement transitions side by side.
class LiveSymbolsExample extends ExamplePage {
  const LiveSymbolsExample({super.key})
    : super(
        const Icon(Icons.local_taxi),
        'Live Symbols (Placement Transitions)',
        category: ExampleCategory.layers,
      );

  @override
  Widget build(BuildContext context) => const _LiveSymbolsBody();
}

/// How the example handles MapLibre's placement transitions.
enum _Mode {
  /// MapLibre's default: symbols fade in, and live data flickers.
  on,

  /// `placementTransitionsEnabled: false` on the widget: no fade anywhere.
  off,

  /// Transitions off only around each source update.
  offDuringUpdates,
}

class _LiveSymbolsBody extends StatefulWidget {
  const _LiveSymbolsBody();

  @override
  State<_LiveSymbolsBody> createState() => _LiveSymbolsBodyState();
}

class _LiveSymbolsBodyState extends State<_LiveSymbolsBody> {
  static const _sourceId = 'live_vehicles';
  static const _layerId = 'live_vehicles_symbols';
  static const _vehicleCount = 12;
  static const LatLng _center = ExampleConstants.sydneyCenter;

  final Random _random = Random(7);
  late final List<LatLng> _positions = [
    for (var i = 0; i < _vehicleCount; i++)
      LatLng(
        _center.latitude + (_random.nextDouble() - 0.5) * 0.02,
        _center.longitude + (_random.nextDouble() - 0.5) * 0.02,
      ),
  ];

  MapLibreMapController? _controller;
  bool _layerReady = false;
  _Mode _mode = _Mode.on;
  Timer? _timer;
  int _tick = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    await addImageFromAsset(
      controller,
      'vehicle',
      'assets/symbols/custom-marker.png',
    );
    await controller.addGeoJsonSource(_sourceId, _vehicles());
    await controller.addSymbolLayer(
      _sourceId,
      _layerId,
      const SymbolLayerProperties(
        iconImage: 'vehicle',
        iconSize: 0.8,
        iconAllowOverlap: true,
        textField: [Expressions.get, 'label'],
        textSize: 12,
        textOffset: [0, 1.6],
        textAllowOverlap: true,
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.5,
      ),
    );
    if (!mounted) return;
    setState(() => _layerReady = true);
    _startUpdates();
  }

  /// The vehicles as a FeatureCollection. Every few ticks some of them go
  /// offline and come back, which is when the flicker is easiest to see.
  Map<String, dynamic> _vehicles() => {
    'type': 'FeatureCollection',
    'features': [
      for (var i = 0; i < _vehicleCount; i++)
        if ((i + _tick) % 5 != 0)
          {
            'type': 'Feature',
            'id': i,
            'geometry': {
              'type': 'Point',
              'coordinates': [
                _positions[i].longitude,
                _positions[i].latitude,
              ],
            },
            'properties': {'label': 'Car ${i + 1}  ${_tick % 60}s'},
          },
    ],
  };

  void _startUpdates() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _stopUpdates() {
    _timer?.cancel();
    setState(() => _timer = null);
  }

  Future<void> _update() async {
    final controller = _controller;
    if (controller == null || !_layerReady) return;
    _tick++;
    for (var i = 0; i < _vehicleCount; i++) {
      _positions[i] = LatLng(
        _positions[i].latitude + (_random.nextDouble() - 0.5) * 0.0008,
        _positions[i].longitude + (_random.nextDouble() - 0.5) * 0.0008,
      );
    }
    if (_mode == _Mode.offDuringUpdates) {
      // The three calls share one channel, so they reach the map in order:
      // the new data is placed in the frame it arrives, then fades return
      // for the rest of the map.
      await controller.setPlacementTransitionsEnabled(false);
      await controller.setGeoJsonSource(_sourceId, _vehicles());
      await controller.setPlacementTransitionsEnabled(true);
    } else {
      await controller.setGeoJsonSource(_sourceId, _vehicles());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        initialCameraPosition: const CameraPosition(target: _center, zoom: 14),
        styleString: ExampleConstants.demoMapStyle,
        // Only the "Off" mode turns them off for the whole map. In the other
        // two the widget keeps the default and the controller does the rest.
        placementTransitionsEnabled: _mode != _Mode.off,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
      ),
      controls: [_buildControls()],
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.all(ExampleConstants.paddingStandard),
          child: Padding(
            padding: const EdgeInsets.all(ExampleConstants.paddingStandard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Symbols',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The vehicles move every second through setGeoJsonSource, '
                  'and some go offline and come back. With placement '
                  'transitions on, MapLibre fades symbols in, so updated '
                  'ones flicker. Switch the mode to compare.',
                ),
              ],
            ),
          ),
        ),
        ControlGroup(
          title: 'Placement transitions',
          children: [
            ExampleSegmentedButton<_Mode>(
              segments: const [
                ExampleSegment(value: _Mode.on, label: 'On'),
                ExampleSegment(value: _Mode.off, label: 'Off'),
                ExampleSegment(
                  value: _Mode.offDuringUpdates,
                  label: 'Off during updates',
                ),
              ],
              selected: _mode,
              onSelectionChanged: (mode) => setState(() => _mode = mode),
            ),
            Text(switch (_mode) {
              _Mode.on =>
                'MapLibre default. Labels of the base map fade nicely, '
                    'the vehicles flicker on each update.',
              _Mode.off =>
                'placementTransitionsEnabled: false. No flicker, but every '
                    'label on the map, the base map included, pops in '
                    'without fading.',
              _Mode.offDuringUpdates =>
                'setPlacementTransitionsEnabled(false) before each update '
                    'and true after it. No flicker, and the base map keeps '
                    'its fades.',
            }),
          ],
        ),
        ControlGroup(
          title: 'Updates',
          children: [
            ExampleButton(
              label: _timer == null ? 'Start updates' : 'Stop updates',
              icon: _timer == null ? Icons.play_arrow : Icons.stop,
              onPressed:
                  _layerReady
                      ? (_timer == null
                          ? () => setState(_startUpdates)
                          : _stopUpdates)
                      : null,
            ),
          ],
        ),
      ],
    );
  }
}
