---
sidebar_position: 4
---

# Display your first map

Import the maplibre_gl package and use the `MapLibreMap` widget to display a
map.

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State createState() => FullMapState();
}

class MapScreenState extends State<MapScreen> {
  MapLibreMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        onMapCreated: (controller) {
          // Don't add additional annotations here,
          // wait for the onStyleLoadedCallback.
          _mapController = controller;
        },
        initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0)),
        onStyleLoadedCallback: () {
          debugPrint('Map loaded 😎');
        },
      ),
    );
  }
}
```

The result should look something like this:

![First map](../img/first_map.jpg)