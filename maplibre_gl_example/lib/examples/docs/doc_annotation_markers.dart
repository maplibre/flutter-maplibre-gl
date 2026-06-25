import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocAnnotationMarkersExample extends ExamplePage {
  const DocAnnotationMarkersExample({super.key})
    : super(
        const Icon(Icons.location_on),
        'Doc Annotation Markers',
        category: ExampleCategory.annotations,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocAnnotationMarkersBody();
}

class _DocAnnotationMarkersBody extends StatefulWidget {
  const _DocAnnotationMarkersBody();

  @override
  State<_DocAnnotationMarkersBody> createState() =>
      _DocAnnotationMarkersBodyState();
}

class _DocAnnotationMarkersBodyState extends State<_DocAnnotationMarkersBody> {
  MapLibreMapController? _controller;

  static const List<Map<String, Object>> _landmarks = [
    {'name': 'Eiffel Tower', 'lat': 48.8584, 'lng': 2.2945},
    {'name': 'Colosseum', 'lat': 41.8902, 'lng': 12.4922},
    {'name': 'Sagrada Familia', 'lat': 41.4036, 'lng': 2.1744},
    {'name': 'Acropolis', 'lat': 37.9715, 'lng': 23.7267},
    {'name': 'Big Ben', 'lat': 51.5007, 'lng': -0.1246},
  ];

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onSymbolTapped(Symbol symbol) {
    final name = symbol.options.textField ?? 'Marker';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(name),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    for (final landmark in _landmarks) {
      await ctrl.addSymbol(
        SymbolOptions(
          geometry: LatLng(
            (landmark['lat']! as num).toDouble(),
            (landmark['lng']! as num).toDouble(),
          ),
          iconImage: 'marker-15',
          iconSize: 2.0,
          iconColor: '#E74C3C',
          textField: landmark['name']! as String,
          textOffset: const Offset(0, 1.5),
          textAnchor: 'top',
          textSize: 13,
          textHaloColor: '#ffffff',
          textHaloWidth: 2,
        ),
      );
    }
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
          target: LatLng(45.0, 8.0),
          zoom: 3.8,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }
}
