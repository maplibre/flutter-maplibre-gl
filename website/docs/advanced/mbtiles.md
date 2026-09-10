# MBTiles

MBTiles is a SQLite archive of map tiles (raster PNG/JPEG or vector MVT). MapLibre Native can read one from disk through the `mbtiles://` URL scheme, so you can ship a regional extract and show it with no tile server.

!!! warning "Android and iOS only"
    `mbtiles://` is implemented by MapLibre Native. It is not available on web
    (MapLibre GL JS has no SQLite reader). Guard this code with `if (!kIsWeb)`,
    or convert the file to [PMTiles](pmtiles.md) if you also need web.

This is not the [offline regions](offline-regions.md) API. Offline regions
download tiles from a style URL into MapLibre's cache. An `.mbtiles` file is a
single file you already have.

## The file has to be on disk

The native engines open the SQLite file themselves. They cannot read the Flutter
asset bundle, so `mbtiles://assets/map.mbtiles` fails with `unable to open
database file`. Copy the file out of assets (or download it) and pass an
**absolute** path.

```yaml
flutter:
  assets:
    - assets/map.mbtiles
```

```dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String> copyMbtilesToCache(String assetKey) async {
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

`mbtiles://` plus that absolute path is three slashes after the scheme:
`mbtiles:///data/.../map.mbtiles`. Do not prefix `file://`.

The system may purge the cache directory. Use
`getApplicationDocumentsDirectory()` if the copy should survive that.

## Raster `.mbtiles`

Add the source after the style has loaded (`onStyleLoadedCallback`):

```dart
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<void> addRasterMbtiles(MapLibreMapController controller) async {
  if (kIsWeb) return;

  final path = await copyMbtilesToCache('assets/map.mbtiles');
  await controller.addSource(
    'mbtiles',
    RasterSourceProperties(
      tiles: ['mbtiles://$path'],
      tileSize: 256,
      attribution: '© OpenStreetMap contributors',
    ),
  );
  await controller.addRasterLayer(
    'mbtiles',
    'mbtiles-layer',
    const RasterLayerProperties(),
  );
}
```

## Vector `.mbtiles`

A vector archive is a `VectorSourceProperties` with `url`, not `tiles`. Layers
still need `sourceLayer` (the name inside the archive, for example `building`
or `water`):

```dart
Future<void> addVectorMbtiles(MapLibreMapController controller) async {
  if (kIsWeb) return;

  final path = await copyMbtilesToCache('assets/map.mbtiles');
  await controller.addSource(
    'mbtiles',
    VectorSourceProperties(
      url: 'mbtiles://$path',
      attribution: '© OpenStreetMap contributors',
    ),
  );
  await controller.addFillLayer(
    'mbtiles',
    'water',
    const FillLayerProperties(fillColor: '#a8d5e5'),
    sourceLayer: 'water',
  );
}
```

## Style JSON

You can also put the URL in a style document. Because the path is absolute and
only known at runtime, load the JSON as a string, substitute the path, then
pass the result as `styleString`:

```dart
Future<String> loadMbtilesStyle() async {
  final path = await copyMbtilesToCache('assets/map.mbtiles');
  var style = await rootBundle.loadString('assets/mbtiles_style.json');
  return style.replaceAll('___MBTILES_URI___', 'mbtiles://$path');
}
```

```json
{
  "version": 8,
  "sources": {
    "offline": {
      "type": "raster",
      "tiles": ["___MBTILES_URI___"],
      "tileSize": 256
    }
  },
  "layers": [
    {
      "id": "offline",
      "type": "raster",
      "source": "offline"
    }
  ]
}
```

For a vector archive use `"type": "vector"` and `"url": "___MBTILES_URI___"`
instead of `tiles`.

## Large files

Small extracts (a few MB) usually just work. Around tens of MB, set `minzoom`
and `maxzoom` on the source to the range actually present in the file, or tiles
can fail to appear when zooming. The same mismatch shows up as the map
appearing at a different zoom than it disappears.

## PMTiles instead

If you also need web, or would rather not copy a SQLite file out of assets,
convert the archive and follow the [PMTiles](pmtiles.md) guide:

```
pmtiles convert input.mbtiles output.pmtiles
```
