import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/constants.dart';

/// A page that demonstrates switching between multiple map styles in MapLibre GL.
///
/// This example page shows how to dynamically change the map's visual appearance
/// by switching between different style configurations, allowing users to see
/// how the same geographic data can be rendered with various themes and styling options.
///
/// The styles include a remote style, an embedded minimal style, and styles loaded from assets.
class MultiStyleSwitchPage extends ExamplePage {
  const MultiStyleSwitchPage({super.key})
      : super(const Icon(Icons.style), 'Multi style switch',
            category: ExampleCategory.basics);

  @override
  Widget build(BuildContext context) => const _MultiStyleSwitchBody();
}

class _MultiStyleSwitchBody extends StatefulWidget {
  const _MultiStyleSwitchBody();

  @override
  State<_MultiStyleSwitchBody> createState() => _MultiStyleSwitchBodyState();
}

class _MultiStyleSwitchBodyState extends State<_MultiStyleSwitchBody> {
  MapLibreMapController? _controller;
  int _currentIndex = 0;
  bool _isSwitching = false;

  CameraPosition? _lastCamera;

  // Demo styles
  static const String _remoteStyle = ExampleConstants.demoMapStyle;
  static const String _embeddedMinimalStyle =
      '{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#90EE90"}}]}';
  static const String _assetStyle = 'assets/style.json';
  static const String _osmAssetStyle = 'assets/osm_style.json';

  late final List<_StyleEntry> _styles = [
    const _StyleEntry('Remote demo style', _remoteStyle),
    const _StyleEntry('Empty JSON string', _embeddedMinimalStyle),
    const _StyleEntry('Asset style', _assetStyle),
    const _StyleEntry('OSM Asset style', _osmAssetStyle),
  ];

  Future<void> _applyStyle(int index) async {
    if (_controller == null) return;
    setState(() => _isSwitching = true);

    final entry = _styles[index];

    try {
      await _controller!.setStyle(entry.styleString);
    } catch (e, st) {
      print(
          'MultiStyleSwitchPage: Failed to set style ${entry.label}: $e\n$st');
      // Fallback to remote style
      await _controller!.setStyle(_remoteStyle);
      _currentIndex = 0;
    }
  }

  Future<void> _onStyleLoaded() async {
    // Restore camera if we had one pending.
    if (_lastCamera != null && _controller != null) {
      await _controller!
          .moveCamera(CameraUpdate.newCameraPosition(_lastCamera!));
    }
    if (mounted) {
      setState(() => _isSwitching = false);
    }
  }

  void _onMapCreated(MapLibreMapController c) {
    _controller = c;
    c.addListener(() {
      // Listen to camera changes to keep track of last position.
      if (!c.isCameraMoving) return;
      _lastCamera = c.cameraPosition;
    });
  }

  void _onCameraIdle() {
    if (_controller == null) return;
    _lastCamera ??= const CameraPosition(target: LatLng(0, 0), zoom: 2);
  }

  Future<void> _cycleStyle() async {
    if (_isSwitching) return;

    _currentIndex = (_currentIndex + 1) % _styles.length;
    await _applyStyle(_currentIndex);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = _styles[_currentIndex];
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            trackCameraPosition: true,
            initialCameraPosition:
                const CameraPosition(target: LatLng(0, 0), zoom: 2),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onCameraIdle: _onCameraIdle,
            attributionButtonPosition: AttributionButtonPosition.topRight,
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
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Current style: ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                              children: [
                                TextSpan(
                                  text: current.label,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isSwitching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Switching...'),
                              ],
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: _cycleStyle,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Change'),
                          ),
                      ],
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

class _StyleEntry {
  final String label;
  final String styleString;
  const _StyleEntry(this.label, this.styleString);
}
