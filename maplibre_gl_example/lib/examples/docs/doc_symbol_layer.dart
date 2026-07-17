import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';
import '../../util.dart';

class DocSymbolLayerExample extends ExamplePage {
  const DocSymbolLayerExample({super.key})
    : super(
        const Icon(Icons.place),
        'Doc Symbol Layer',
        category: ExampleCategory.layers,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocSymbolLayerBody();
}

class _DocSymbolLayerBody extends StatefulWidget {
  const _DocSymbolLayerBody();

  @override
  State<_DocSymbolLayerBody> createState() => _DocSymbolLayerBodyState();
}

class _DocSymbolLayerBodyState extends State<_DocSymbolLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'cities-source';
  static const _layerId = 'cities-layer';

  static const List<Map<String, Object>> _cities = [
    {'name': 'Paris', 'lat': 48.8566, 'lng': 2.3522},
    {'name': 'London', 'lat': 51.5074, 'lng': -0.1278},
    {'name': 'Berlin', 'lat': 52.5200, 'lng': 13.4050},
    {'name': 'Madrid', 'lat': 40.4168, 'lng': -3.7038},
    {'name': 'Rome', 'lat': 41.9028, 'lng': 12.4964},
    {'name': 'Amsterdam', 'lat': 52.3676, 'lng': 4.9041},
    {'name': 'Vienna', 'lat': 48.2082, 'lng': 16.3738},
    {'name': 'Zurich', 'lat': 47.3769, 'lng': 8.5417},
    {'name': 'Brussels', 'lat': 50.8503, 'lng': 4.3517},
    {'name': 'Prague', 'lat': 50.0755, 'lng': 14.4378},
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    await addImageFromAsset(
      ctrl,
      'doc-marker',
      'assets/symbols/custom-marker.png',
    );

    await ctrl.addGeoJsonSource(_sourceId, {
      'type': 'FeatureCollection',
      'features':
          _cities
              .map(
                (c) => {
                  'type': 'Feature',
                  'properties': {'name': c['name']},
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [c['lng'], c['lat']],
                  },
                },
              )
              .toList(),
    });

    await ctrl.addSymbolLayer(
      _sourceId,
      _layerId,
      const SymbolLayerProperties(
        iconImage: 'doc-marker',
        iconSize: 0.8,
        iconOffset: [0, -10],
        iconAllowOverlap: true,
        textField: [Expressions.get, 'name'],
        textSize: 13,
        textColor: '#1a1a2e',
        textHaloColor: '#ffffff',
        textHaloWidth: 2,
        textOffset: [0, 1.2],
        textAnchor: 'top',
        textAllowOverlap: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      mapOnly: true,
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: LatLng(48.5, 10.0),
          zoom: 3.8,
        ),
      ),
    );
  }
}
