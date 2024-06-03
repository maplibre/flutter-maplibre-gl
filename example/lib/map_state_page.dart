import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/main.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';

class MapStatePage extends StatefulWidget {
  const MapStatePage({super.key});

  @override
  State<MapStatePage> createState() => _MapStatePageState();
}

class _MapStatePageState extends State<MapStatePage> {
  MaplibreMapController? controller;

  void onMapCreated(MaplibreMapController controller) {
    setState(() {
      this.controller = controller;
    });
  }

  void _showSnackbar(String content) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(content)));
  }

  void displaySources() async {
    if (controller == null) {
      return;
    }
    List<String> sources = await controller!.getSourceIds();
    _showSnackbar('Sources: ${sources.map((e) => '"$e"').join(', ')}');
  }

  void displayLayers() async {
    if (controller == null) {
      return;
    }
    List<String> layers = (await controller!.getLayerIds()).cast<String>();
    _showSnackbar('Layers: ${layers.map((e) => '"$e"').join(', ')}');
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      page: ExamplePage.mapState,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: controller == null ? null : displayLayers,
                  child: const Text('Get map layers'),
                ),
                TextButton(
                  onPressed: controller == null ? null : displaySources,
                  child: const Text('Get map sources'),
                )
              ],
            ),
          ),
          Expanded(
            child: MaplibreMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-33.852, 151.211),
                zoom: 2,
              ),
              onMapCreated: onMapCreated,
              annotationOrder: const [],
              styleString: MaplibreStyles.demo,
            ),
          ),
        ],
      ),
    );
  }
}
