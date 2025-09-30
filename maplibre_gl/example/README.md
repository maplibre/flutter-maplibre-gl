# MapLibre Flutter example

This folder contains a **small, self‑contained example** used by pub.dev to display how to start with `maplibre_gl`.

What it demonstrates:
* Creating a `MaplibreMap` widget
* Loading a public style (`https://demotiles.maplibre.org/style.json`)
* Animating the camera with a floating action button

Run locally from the repository root:

```bash
cd maplibre_gl/example
flutter run
```

Looking for richer demos (offline regions, annotations, multiple pages, PMTiles, etc.)? 

See the full [example app](https://github.com/maplibre/flutter-maplibre-gl/tree/main/maplibre_gl_example)!

---
# Code example

```dart
void main() {
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
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

```