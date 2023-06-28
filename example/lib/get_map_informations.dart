import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

import 'page.dart';

class GetMapInfoPage extends ExamplePage {
  const GetMapInfoPage({super.key})
      : super(const Icon(Icons.info), 'Get map state');

  @override
  Widget build(BuildContext context) {
    return const GetMapInfoBody();
  }
}

class GetMapInfoBody extends StatefulWidget {
  const GetMapInfoBody({super.key});

  @override
  State<GetMapInfoBody> createState() => _GetMapInfoBodyState();
}

class _GetMapInfoBodyState extends State<GetMapInfoBody> {
  MaplibreMapController? controller;
  String data = '';

  void onMapCreated(MaplibreMapController controller) {
    setState(() {
      this.controller = controller;
    });
  }

  void displaySources() async {
    if (controller == null) {
      return;
    }
    List<String> sources = await controller!.getSourceIds();
    setState(() {
      data = 'Sources: ${sources.map((e) => '"$e"').join(', ')}';
    });
  }

  void displayLayers() async {
    if (controller == null) {
      return;
    }
    List<String> layers = (await controller!.getLayerIds()).cast<String>();
    setState(() {
      data = 'Layers: ${layers.map((e) => '"$e"').join(', ')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 300.0,
            height: 200.0,
            child: MaplibreMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-33.852, 151.211),
                zoom: 11.0,
              ),
              onMapCreated: onMapCreated,
              compassEnabled: false,
              annotationOrder: const [],
              myLocationEnabled: false,
              styleString: '''{
                "version": 8,
                "sources": {
                  "OSM": {
                    "type": "raster",
                    "tiles": [
                      "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      "https://b.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      "https://c.tile.openstreetmap.org/{z}/{x}/{y}.png"
                    ],
                    "tileSize": 256,
                    "attribution": "© OpenStreetMap contributors",
                    "maxzoom": 18
                  }
                },
                "layers": [
                  {
                    "id": "OSM-layer",
                    "source": "OSM",
                    "type": "raster"
                  }
                ]
              }''',
            ),
          ),
        ),
        const Center(child: Text('© OpenStreetMap contributors')),
        Expanded(
            child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Center(child: Text(data)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: controller == null ? null : displayLayers,
                child: const Text('Get map layers'),
              ),
              ElevatedButton(
                onPressed: controller == null ? null : displaySources,
                child: const Text('Get map sources'),
              )
            ],
          ),
        )),
      ],
    );
  }
}
