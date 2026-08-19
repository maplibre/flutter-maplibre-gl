import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating a hover effect using feature state (web only).
///
/// This example combines onMapMouseMove and queryRenderedFeatures to detect
/// which feature the mouse is over, then uses setFeatureState to update the
/// styling dynamically without touching the source data.
///
/// The page is web only because mouse events do not exist on the other
/// platforms. Feature state itself also runs on Android; its cross-platform,
/// tap-driven side is demonstrated by the Feature State page under
/// Layers & Sources.
///
/// Important notes:
/// - Uses onMapMouseMove + manual feature querying for vector tile layers
/// - onFeatureHover works with annotation objects (addFill, addCircle, etc.)
///   and could be used instead of manual querying
///
/// Based on: https://maplibre.org/maplibre-gl-js/docs/examples/create-a-hover-effect/
class HoverEffectExample extends ExamplePage {
  const HoverEffectExample({super.key})
    : super(
        const Icon(Icons.touch_app),
        'Hover Effect',
        category: ExampleCategory.interaction,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _HoverEffectBody();
}

class _HoverEffectBody extends StatefulWidget {
  const _HoverEffectBody();

  @override
  State<_HoverEffectBody> createState() => _HoverEffectBodyState();
}

class _HoverEffectBodyState extends State<_HoverEffectBody> {
  MapLibreMapController? _controller;
  String? _hoveredStateName;
  String? _hoveredStateId;

  static const _sourceName = 'states';
  static const _fillLayerId = 'state-fills';
  static const _borderLayerId = 'state-borders';

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
    _setupHoverListeners();
  }

  Future<void> _onStyleLoaded() async {
    await _addStatesLayer();
  }

  Future<void> _addStatesLayer() async {
    if (_controller == null) return;

    // promoteId promotes STATE_ID to be the feature id. It is an option only
    // MapLibre GL JS supports, which is fine here since this page only runs
    // on web.
    await _controller!.addSource(
      _sourceName,
      const GeojsonSourceProperties(
        data:
            'https://maplibre.org/maplibre-gl-js/docs/assets/us_states.geojson',
        promoteId: 'STATE_ID',
      ),
    );

    // Add fill layer that uses feature-state to control opacity
    await _controller!.addLayer(
      _sourceName,
      _fillLayerId,
      const FillLayerProperties(
        fillColor: '#627BC1',
        fillOpacity: [
          'case',
          [
            'boolean',
            ['feature-state', 'hover'],
            false,
          ],
          1.0,
          0.5,
        ],
      ),
      enableInteraction: true,
    );

    // Add border layer
    await _controller!.addLayer(
      _sourceName,
      _borderLayerId,
      const LineLayerProperties(lineColor: '#627BC1', lineWidth: 2),
      enableInteraction: false,
    );
  }

  void _setupHoverListeners() {
    if (_controller == null) return;

    // Listen to mouse move events and query features manually
    // NOTE: You could also use onFeatureHover listener for annotation layers
    _controller!.onMapMouseMove.add((point, coordinates) {
      unawaited(_handleMouseMove(point));
    });
  }

  Future<void> _handleMouseMove(math.Point<double> point) async {
    // Query rendered features at the mouse position
    final features = await _controller?.queryRenderedFeatures(
      point,
      [_fillLayerId], // Only query our states layer
      null,
    );
    if (features != null && features.isNotEmpty) {
      // Get the first state feature
      final feature = features.first;
      final featureId = feature['id']?.toString();
      final stateName = feature['properties']?['STATE_NAME'] as String?;

      if (featureId != null && featureId != _hoveredStateId) {
        // Remove hover state from previous feature
        if (_hoveredStateId != null) {
          await _controller?.removeFeatureState(
            _sourceName,
            featureId: _hoveredStateId,
            stateKey: 'hover',
          );
        }

        // Set hover state on new feature
        await _controller?.setFeatureState(_sourceName, featureId, {
          'hover': true,
        });

        if (mounted) {
          setState(() {
            _hoveredStateId = featureId;
            _hoveredStateName = stateName ?? 'Feature ID: $featureId';
          });
        }
      }
    } else {
      // The mouse is not over any state feature
      if (_hoveredStateId != null) {
        await _controller?.removeFeatureState(
          _sourceName,
          featureId: _hoveredStateId,
          stateKey: 'hover',
        );

        if (mounted) {
          setState(() {
            _hoveredStateId = null;
            _hoveredStateName = null;
          });
        }
      }
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
          target: LatLng(37.830348, -100.486052),
          zoom: 2,
        ),
        trackCameraPosition: true,
      ),
      controls: [
        const InfoCard(
          title: 'Hover Effect',
          subtitle: 'Move your mouse over US states to see the hover effect',
          icon: Icons.touch_app,
        ),
        if (_hoveredStateName != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hovering:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hoveredStateName!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hover over a state to see it highlighted',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Uses onMapMouseMove for position tracking\n'
                  '• Calls queryRenderedFeatures at mouse position\n'
                  '• Uses feature-state to track hover status\n'
                  '• Fill opacity changes based on hovered feature state',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
