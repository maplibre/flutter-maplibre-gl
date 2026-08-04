import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating highlighting features using feature state.
///
/// This example shows how to combine map events and queryRenderedFeatures
/// to detect which feature the user is pointing at, then use setFeatureState
/// to update styling dynamically without touching the source data. On web the
/// highlight follows the mouse (onMapMouseMove); on Android, which has no
/// mouse events, tapping a state highlights it instead.
///
/// Important notes:
/// - Feature state runs on web and Android. It is not available on iOS,
///   because the MapLibre iOS SDK does not expose the API yet.
/// - promoteId is only supported by MapLibre GL JS, so it is passed on web
///   only. On Android, features are keyed by their top-level `id` member,
///   which this dataset provides.
/// - onFeatureHover works with annotation objects (addFill, addCircle, etc.)
///   and could be used instead of manual querying on web.
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

  /// Feature state needs support in the underlying MapLibre SDK, which web
  /// and Android have. The iOS SDK does not expose the API yet.
  static bool get isSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Hover Effect Example',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This example is available on web and Android. It is not '
                'available on iOS yet, because the MapLibre iOS SDK does not '
                'expose the feature state API.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return const _HoverEffectBody();
  }
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

    // promoteId promotes STATE_ID to be the feature id, but only MapLibre GL
    // JS supports it: the Android SDK does not expose promoteId, so on
    // Android features are keyed by the top-level `id` member each feature in
    // this dataset already carries.
    await _controller!.addSource(
      _sourceName,
      const GeojsonSourceProperties(
        data:
            'https://maplibre.org/maplibre-gl-js/docs/assets/us_states.geojson',
        promoteId: kIsWeb ? 'STATE_ID' : null,
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
      // On web this drives the pointer cursor over the states. On Android the
      // layer stays non-interactive so taps reach onMapClick instead of being
      // swallowed by the plugin's own feature-tap handling.
      enableInteraction: kIsWeb,
    );

    // Add border layer
    await _controller!.addLayer(
      _sourceName,
      _borderLayerId,
      const LineLayerProperties(
        lineColor: '#627BC1',
        lineWidth: 2,
      ),
      enableInteraction: false,
    );
  }

  void _setupHoverListeners() {
    if (_controller == null) return;
    // Mouse events only exist on web; Android uses onMapClick on the map
    // widget instead, funneling into the same feature lookup.
    if (!kIsWeb) return;

    // Listen to mouse move events and query features manually
    // NOTE: You could also use onFeatureHover listener for annotation layers
    _controller!.onMapMouseMove.add((
      point,
      coordinates,
    ) {
      unawaited(_updateHighlightedFeature(point));
    });
  }

  void _onMapClick(math.Point<double> point, LatLng coordinates) {
    unawaited(_updateHighlightedFeature(point));
  }

  Future<void> _updateHighlightedFeature(math.Point<double> point) async {
    // Query rendered features at the pointer position
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
        await _controller?.setFeatureState(
          _sourceName,
          featureId,
          {'hover': true},
        );

        if (mounted) {
          setState(() {
            _hoveredStateId = featureId;
            _hoveredStateName = stateName ?? 'Feature ID: $featureId';
          });
        }
      }
    } else {
      // The pointer is not over any state feature
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
        onMapClick: kIsWeb ? null : _onMapClick,
        initialCameraPosition: const CameraPosition(
          target: LatLng(37.830348, -100.486052),
          zoom: 2,
        ),
        trackCameraPosition: true,
      ),
      controls: [
        const InfoCard(
          title: 'Hover Effect',
          subtitle:
              kIsWeb
                  ? 'Move your mouse over US states to see the hover effect'
                  : 'Tap a US state to highlight it',
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
                          kIsWeb ? 'Hovering:' : 'Selected:',
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
                      kIsWeb
                          ? 'Hover over a state to see it highlighted'
                          : 'Tap a state to see it highlighted',
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
                  kIsWeb
                      ? '• Uses onMapMouseMove for position tracking\n'
                          '• Calls queryRenderedFeatures at mouse position\n'
                          '• Uses feature-state to track hover status\n'
                          '• Fill opacity changes based on hovered feature state'
                      : '• Uses onMapClick for position tracking\n'
                          '• Calls queryRenderedFeatures at the tap position\n'
                          '• Uses feature-state to track the selection\n'
                          '• Fill opacity changes based on selected feature state',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Feature state runs on web and Android. iOS is not '
                  'supported yet, because the MapLibre iOS SDK does not '
                  'expose the API.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
