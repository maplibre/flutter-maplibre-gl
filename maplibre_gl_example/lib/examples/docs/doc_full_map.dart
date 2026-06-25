import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocFullMapExample extends ExamplePage {
  const DocFullMapExample({super.key})
    : super(
        const Icon(Icons.map),
        'Doc Full Map',
        category: ExampleCategory.basics,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocFullMapBody();
}

class _DocFullMapBody extends StatelessWidget {
  const _DocFullMapBody();

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      mapOnly: true,
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        initialCameraPosition: const CameraPosition(
          target: LatLng(20.0, 0.0),
          zoom: 1.8,
        ),
      ),
    );
  }
}
