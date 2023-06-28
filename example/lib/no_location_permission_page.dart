import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

import 'page.dart';

class NoLocationPermissionPage extends ExamplePage {
  const NoLocationPermissionPage({super.key})
      : super(
          const Icon(Icons.gps_off),
          'Using a map without user location/permission',
          needsLocationPermission: false,
        );

  @override
  Widget build(BuildContext context) {
    return const NoLocationPermissionBody();
  }
}

class NoLocationPermissionBody extends StatefulWidget {
  const NoLocationPermissionBody({super.key});

  @override
  State<NoLocationPermissionBody> createState() =>
      _NoLocationPermissionBodyState();
}

class _NoLocationPermissionBodyState extends State<NoLocationPermissionBody> {
  @override
  Widget build(BuildContext context) {
    return MaplibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-33.852, 151.211),
        zoom: 11.0,
      ),
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
    );
  }
}
