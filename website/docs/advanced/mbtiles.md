# MBTiles

An `.mbtiles` file is a SQLite archive of map tiles. MapLibre Native reads it from disk through the `mbtiles://` URL scheme, so you can ship a regional map with no tile server. Android and iOS only, see [Platform support](#platform-support).

## How it works

The native engine opens the file itself, so it cannot read it from the Flutter asset bundle: `mbtiles://assets/map.mbtiles` fails with `unable to open database file`. Three steps:

1. Bundle the file as a Flutter asset.
2. Copy it to a file on disk at startup.
3. Point a source at `mbtiles://` plus the absolute path of that copy.

## Step 1: Bundle the file

Add [`path_provider`](https://pub.dev/packages/path_provider) to your dependencies (it is not a dependency of `maplibre_gl`) and register the asset:

```yaml
dependencies:
  path_provider: ^2.1.5

flutter:
  assets:
    - assets/map_v1.mbtiles
```

## Step 2: Copy it to disk

```dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String> copyAssetToDisk(String assetKey) async {
  final cache = await getApplicationCacheDirectory();
  final out = File('${cache.path}/$assetKey');
  if (!out.existsSync()) {
    final data = await rootBundle.load(assetKey);
    await out.parent.create(recursive: true);
    await out.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
  return out.path;
}
```

The copy is skipped when the file already exists, so later launches are fast. It also means an app update that ships new tiles under the same name keeps showing the old copy. Put a version in the file name (`map_v1.mbtiles`, then `map_v2.mbtiles`) and rename the asset whenever its content changes.

## Step 3: Add the source

Add the source and a layer in `onStyleLoadedCallback`:

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MbtilesMap extends StatefulWidget {
  const MbtilesMap({super.key});

  @override
  State<MbtilesMap> createState() => _MbtilesMapState();
}

class _MbtilesMapState extends State<MbtilesMap> {
  MapLibreMapController? _controller;

  Future<void> _onStyleLoaded() async {
    final path = await copyAssetToDisk('assets/map_v1.mbtiles');
    await _controller!.addSource(
      'local-tiles',
      RasterSourceProperties(
        tiles: ['mbtiles://$path'],
        tileSize: 256,
        attribution: '© OpenStreetMap contributors',
      ),
    );
    await _controller!.addRasterLayer(
      'local-tiles',
      'local-tiles-layer',
      const RasterLayerProperties(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(48.85, 2.35),
        zoom: 10,
      ),
      onMapCreated: (controller) => _controller = controller,
      onStyleLoadedCallback: _onStyleLoaded,
    );
  }
}
```

`path` is absolute, so the URL has three slashes after the scheme: `mbtiles:///data/.../map_v1.mbtiles`. Do not add `file://`.

For a vector archive, use `VectorSourceProperties(url: 'mbtiles://$path')` instead, and pass `sourceLayer` (a layer name inside the archive, such as `water`) to `addFillLayer`, `addLineLayer` and the other layer methods.

## Platform support

`mbtiles://` is implemented by MapLibre Native, so it works on Android and iOS. MapLibre GL JS cannot read MBTiles, so on web convert the file with `pmtiles convert input.mbtiles output.pmtiles` and follow the [PMTiles](pmtiles.md) guide.
