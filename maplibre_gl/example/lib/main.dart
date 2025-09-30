import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _ExampleHomePage(),
    );
  }
}

class _ExampleHomePage extends StatefulWidget {
  const _ExampleHomePage();

  @override
  State<_ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<_ExampleHomePage> {
  MapLibreMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('maplibre_gl minimal example')),
      body: MapLibreMap(
        // ignore: avoid_redundant_argument_values --- EXAMPLE ---
        styleString: 'https://demotiles.maplibre.org/style.json',
        onMapCreated: (c) => _controller = c,
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 1.0,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final c = _controller;
          if (c == null) return;
          await c.animateCamera(
            CameraUpdate.newCameraPosition(
              const CameraPosition(target: LatLng(0, 0), zoom: 3),
            ),
          );
        },
        child: const Icon(Icons.flight),
      ),
    );
  }
}
