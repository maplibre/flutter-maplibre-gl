import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating the feature state API.
///
/// Tapping a US state toggles `{'selected': true}` on it with
/// setFeatureState, and the fill layer's paint reads that flag back through
/// a ["feature-state", ...] expression. The source data is never touched, so
/// restyling stays a cheap per-feature call instead of a re-feed of the
/// whole GeoJSON collection.
///
/// The page exercises all three calls: setFeatureState to select,
/// removeFeatureState with featureId and stateKey to deselect one state,
/// a bare removeFeatureState to reset the whole source, and getFeatureState
/// to read back what the platform actually stores.
///
/// Feature state runs on web and Android. It is not available on iOS,
/// because the MapLibre iOS SDK does not expose the API yet.
class FeatureStateExample extends ExamplePage {
  const FeatureStateExample({super.key})
    : super(
        const Icon(Icons.fact_check),
        'Feature State',
        category: ExampleCategory.layers,
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
              Icon(Icons.fact_check, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Feature State Example',
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
    return const _FeatureStateBody();
  }
}

class _FeatureStateBody extends StatefulWidget {
  const _FeatureStateBody();

  @override
  State<_FeatureStateBody> createState() => _FeatureStateBodyState();
}

class _FeatureStateBodyState extends State<_FeatureStateBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'states';
  static const _fillLayerId = 'state-fills';
  static const _borderLayerId = 'state-borders';

  /// Ids of the currently selected features, exactly as the platform
  /// reported them.
  final Set<String> _selectedIds = {};

  String? _lastTouchedId;
  String? _lastTouchedName;
  Map<String, dynamic>? _lastReportedState;

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await _addStatesLayer();
  }

  Future<void> _addStatesLayer() async {
    final controller = _controller;
    if (controller == null) return;

    // On web promoteId makes the STATE_ID property the feature id; the
    // Android SDK does not expose promoteId, so there the features are keyed
    // by the top-level `id` member each feature in this dataset also carries.
    await controller.addSource(
      _sourceId,
      const GeojsonSourceProperties(
        data:
            'https://maplibre.org/maplibre-gl-js/docs/assets/us_states.geojson',
        promoteId: kIsWeb ? 'STATE_ID' : null,
      ),
    );

    await controller.addLayer(
      _sourceId,
      _fillLayerId,
      const FillLayerProperties(
        // A feature nobody touched yet has no state, so the feature-state
        // expression returns null: the `false` fallback is what keeps
        // unselected states on the default paint.
        fillColor: [
          'case',
          [
            'boolean',
            ['feature-state', 'selected'],
            false,
          ],
          '#F39C12',
          '#627BC1',
        ],
        fillOpacity: [
          'case',
          [
            'boolean',
            ['feature-state', 'selected'],
            false,
          ],
          0.8,
          0.4,
        ],
      ),
      // Keep the layer out of the plugin's own feature-tap handling, which
      // would otherwise swallow the tap on Android before onMapClick fires.
      enableInteraction: false,
    );

    await controller.addLayer(
      _sourceId,
      _borderLayerId,
      const LineLayerProperties(lineColor: '#627BC1', lineWidth: 2),
      enableInteraction: false,
    );
  }

  void _onMapClick(math.Point<double> point, LatLng coordinates) {
    unawaited(_toggleFeatureAt(point));
  }

  Future<void> _toggleFeatureAt(math.Point<double> point) async {
    final controller = _controller;
    if (controller == null) return;

    final features = await controller.queryRenderedFeatures(point, [
      _fillLayerId,
    ], null);
    if (features.isEmpty) return;

    final feature = features.first;
    // Always pass the id queryRenderedFeatures reports, never one computed
    // here: with promoteId the web id is the promoted STATE_ID string while
    // on Android it is the top-level integer, and in this dataset several of
    // them differ by zero padding ("04" against 4). An id built on the Dart
    // side would silently miss on one platform or the other.
    final featureId = feature['id']?.toString();
    if (featureId == null) return;
    final stateName = feature['properties']?['STATE_NAME'] as String?;

    if (_selectedIds.contains(featureId)) {
      // Deselect by dropping only the `selected` key: other keys a real app
      // might keep on the same feature would survive.
      await controller.removeFeatureState(
        _sourceId,
        featureId: featureId,
        stateKey: 'selected',
      );
      _selectedIds.remove(featureId);
    } else {
      await controller.setFeatureState(_sourceId, featureId, {
        'selected': true,
      });
      _selectedIds.add(featureId);
    }

    // Read the state back from the platform instead of echoing what was just
    // written: showing what getFeatureState actually returns is the point of
    // the panel below.
    final reported = await controller.getFeatureState(_sourceId, featureId);

    if (mounted) {
      setState(() {
        _lastTouchedId = featureId;
        _lastTouchedName = stateName ?? 'Feature $featureId';
        _lastReportedState = reported;
      });
    }
  }

  Future<void> _clearAll() async {
    final controller = _controller;
    if (controller == null) return;

    // A bare removeFeatureState resets every feature in the source with a
    // single call; no need to loop over the selected ids.
    await controller.removeFeatureState(_sourceId);

    // Re-read the last touched feature so the panel keeps showing the
    // platform truth instead of a stale map.
    final lastId = _lastTouchedId;
    final reported =
        lastId == null
            ? null
            : await controller.getFeatureState(_sourceId, lastId);

    if (mounted) {
      setState(() {
        _selectedIds.clear();
        _lastReportedState = reported;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        onMapClick: _onMapClick,
        initialCameraPosition: const CameraPosition(
          target: LatLng(37.830348, -100.486052),
          zoom: 2,
        ),
      ),
      controls: [
        const InfoCard(
          title: 'Feature State',
          subtitle: 'Tap a US state to select it, tap it again to deselect it',
          icon: Icons.fact_check,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedIds.length == 1
                        ? '1 state selected'
                        : '${_selectedIds.length} states selected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ExampleButton(
                  label: 'Clear all',
                  icon: Icons.clear,
                  style: ExampleButtonStyle.tonal,
                  onPressed:
                      _selectedIds.isEmpty
                          ? null
                          : () => unawaited(_clearAll()),
                ),
              ],
            ),
          ),
        ),
        if (_lastTouchedId != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$_lastTouchedName (id: $_lastTouchedId)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "getFeatureState('$_sourceId', '$_lastTouchedId')",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_lastReportedState ?? 'null'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
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
                      color: theme.colorScheme.primary,
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
                  '• A tap queries the rendered features and toggles '
                  "{'selected': true} on the hit with setFeatureState\n"
                  '• The fill paint reads the flag back with a '
                  '["feature-state", "selected"] expression, so the source '
                  'data never changes\n'
                  '• Deselecting removes just the selected key; Clear all '
                  'resets the whole source with one bare removeFeatureState\n'
                  '• The panel above shows the raw map getFeatureState '
                  'returns for the last state touched',
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
