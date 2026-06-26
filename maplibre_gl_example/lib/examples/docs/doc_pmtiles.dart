import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class DocPMTilesExample extends ExamplePage {
  const DocPMTilesExample({super.key})
    : super(
        const Icon(Icons.layers_outlined),
        'Doc PMTiles',
        category: ExampleCategory.advanced,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocPMTilesBody();
}

class _DocPMTilesBody extends StatelessWidget {
  const _DocPMTilesBody();

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      mapOnly: true,
      controls: const [],
      map: MapLibreMap(
        styleString: ExampleConstants.pmtilesStyleAsset,
        initialCameraPosition: const CameraPosition(
          target: LatLng(47.0, 8.0),
          zoom: 4.0,
        ),
      ),
    );
  }
}
