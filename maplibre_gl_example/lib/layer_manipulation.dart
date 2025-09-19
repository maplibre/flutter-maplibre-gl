import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';

class LayerManipulationPage extends ExamplePage {
  const LayerManipulationPage({super.key})
      : super(const Icon(Icons.layers), 'Layer Manipulation');

  @override
  Widget build(BuildContext context) {
    return const LayerManipulation();
  }
}

class LayerManipulation extends StatefulWidget {
  const LayerManipulation({super.key});

  @override
  State<LayerManipulation> createState() => _LayerManipulationState();
}

class _LayerManipulationState extends State<LayerManipulation> {
  MapLibreMapController? mapController;
  String currentStyle = '';
  int currentFilterId = 0;
  bool isGeoJsonSourceMode = true;
  int animationStep = 0;
  Timer? _animationTimer;
  bool _isAnimating = false;

  // Sample GeoJSON data for editGeoJsonSource
  final Map<String, dynamic> _sampleGeoJsonData = {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [14.363610, 46.233487, 0.0]
        }
      },
    ]
  };

  // Animated GeoJSON data that changes over time
  Map<String, dynamic> _getAnimatedGeoJsonData(int step) {
    final baseData = Map<String, dynamic>.from(_sampleGeoJsonData);
    final features = List.from(baseData['features']);

    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final coords = List<double>.from(feature['geometry']['coordinates']);
      final angle = (step * 0.1) + (i * 0.5);
      final radius = 0.5 + (i * 0.1);

      coords[0] = coords[0] + radius * cos(angle);
      coords[1] = coords[1] + radius * sin(angle);

      feature['geometry']['coordinates'] = coords;
    }

    baseData['features'] = features;
    return baseData;
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  Future<void> _onStyleLoadedCallback() async {
    if (mapController == null) return;

    // Add a GeoJSON source
    await mapController!.addSource(
      "sample-data",
      GeojsonSourceProperties(data: _sampleGeoJsonData),
    );

    // Add a circle layer
    await mapController!.addCircleLayer(
      "sample-data",
      "sample-circles",
      const CircleLayerProperties(
        circleRadius: 8,
        circleColor: "#ff0000",
        circleStrokeColor: "#ffffff",
        circleStrokeWidth: 2,
      ),
    );

    // Add a symbol layer for labels
    await mapController!.addSymbolLayer(
      "sample-data",
      "sample-labels",
      const SymbolLayerProperties(
        textField: ["get", "name"],
        textFont: ["Open Sans Regular"],
        textSize: 12,
        textColor: "#000000",
        textHaloColor: "#ffffff",
        textHaloWidth: 1,
      ),
    );

    // Get and display current style
    await _getCurrentStyle();
  }

  Future<void> _getCurrentStyle() async {
    if (mapController == null) return;

    try {
      final style = await mapController!.getStyle();
      setState(() {
        currentStyle = style ?? 'No style available';
      });
    } catch (e) {
      setState(() {
        currentStyle = 'Error getting style: $e';
      });
    }
  }

  void _toggleAnimation() {
    if (_isAnimating) {
      _stopAnimation();
    } else {
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (_animationTimer != null) return;

    setState(() {
      isGeoJsonSourceMode = true;
      _isAnimating = true;
    });

    _animationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mapController != null) {
        final newData = _getAnimatedGeoJsonData(animationStep);
        mapController!.setGeoJsonSource("sample-data", newData);

        setState(() {
          animationStep++;
        });
      }
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;

    setState(() {
      _isAnimating = false;
    });
  }

  Future<void> _editGeoJsonUrl() async {
    if (mapController == null) return;

    // Stop animation when switching to URL mode
    _stopAnimation();

    setState(() {
      isGeoJsonSourceMode = false;
    });

    // Use a public GeoJSON URL (earthquakes data)
    await mapController!.editGeoJsonUrl(
      "sample-data",
      "https://docs.mapbox.com/mapbox-gl-js/assets/earthquakes.geojson",
    );
  }

  Future<void> _setLayerFilter() async {
    if (mapController == null) return;

    // Cycle through different filters
    final filters = [
      '["all", ["==", "name", "International Date Line"]]', // Don't show International Date Line
      '["all", ["!=", "name", "International Date Line"]]', // Do show International Date Line
    ];

    final filter = filters[currentFilterId % filters.length];
    await mapController!.setLayerFilter("countries-fill", filter);

    setState(() {
      currentFilterId++;
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 3,
            child: MapLibreMap(
              styleString: MapLibreStyles.demo,
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoadedCallback,
              initialCameraPosition: const CameraPosition(
                target: LatLng(50.0, 10.0),
                zoom: 3.0,
              ),
            ),
          ),

          // Controls
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Layer Manipulation Demo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),

                  // Control buttons
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ElevatedButton(
                        onPressed: _toggleAnimation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isAnimating ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_isAnimating
                            ? 'Stop Animation'
                            : 'Start Animation'),
                      ),
                      if (!kIsWeb) ...[
                        ElevatedButton(
                          onPressed: _editGeoJsonUrl,
                          child: const Text('Show Earthquakes'),
                        ),
                        ElevatedButton(
                          onPressed: _setLayerFilter,
                          child: const Text('Toggle Country Fill'),
                        ),
                        ElevatedButton(
                          onPressed: _getCurrentStyle,
                          child: const Text('Get Style'),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status information
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Mode: ${isGeoJsonSourceMode ? "GeoJSON Source" : "GeoJSON URL"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Filter ID: $currentFilterId'),
                        Text('Animation Step: $animationStep'),
                        Text(
                            'Animation Status: ${_isAnimating ? "Running" : "Stopped"}'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Style information
                  if (currentStyle.isNotEmpty) ...[
                    const Text(
                      'Current Style:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      height: 100,
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          currentStyle,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
