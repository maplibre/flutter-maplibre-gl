# Offline Regions

Offline regions allow users to download a geographic area and use the map without internet access. The map tiles, fonts, and sprites are all stored on-device.

!!! warning "Android and iOS only"
    MapLibre GL JS (web) has no offline API. The offline region feature is only available on Android and iOS. Guard all offline code with `if (!kIsWeb)`.

## How it works

```mermaid
flowchart TD
    APP["Your app"] --> CALL["downloadOfflineRegion(<br/>definition, onEvent)"]
    CALL --> BG["MapLibre Native downloads<br/>tiles in the background"]
    BG --> EV["onEvent(status)<br/>called periodically<br/><small>completed / required count<br/>state: active · complete · inactive</small>"]
    BG --> CACHE["Tiles stored in MapLibre's<br/>SQLite cache on device"]

    classDef root fill:#1f6feb,stroke:#1a5fd0,color:#fff;
    class APP root
```

Once downloaded, the map works offline automatically; no code change needed. When a region is in the cache and the device is offline, MapLibre serves tiles from the local store.

## Step 1: Define the region

`OfflineRegionDefinition` describes what to download:

```dart
import 'package:maplibre_gl/maplibre_gl.dart';

final definition = OfflineRegionDefinition(
  bounds: LatLngBounds(
    southwest: const LatLng(48.7, 2.2),  // Paris area
    northeast: const LatLng(49.0, 2.5),
  ),
  minZoom: 10.0,   // download from zoom 10
  maxZoom: 16.0,   // to zoom 16 (street level)
  mapStyleUrl: MapLibreStyles.openfreemapLiberty,
  includeIdeographs: false,  // set true for CJK character support
);
```

!!! tip "Tile count warning"
    Tile count grows exponentially with zoom levels. A 10×10 km area at zoom 10–16 can be thousands of tiles. Use [MapLibre's tile estimator](https://docs.maplibre.org) to estimate size before prompting users.

## Step 2: Download with a progress callback

```dart
import 'package:flutter/foundation.dart'; // for kIsWeb

Future<void> downloadRegion() async {
  if (kIsWeb) return; // offline not supported on web

  final region = await downloadOfflineRegion(
    definition,
    metadata: {'name': 'Paris Center'},  // arbitrary metadata
    onEvent: (OfflineRegionStatus status) {
      final progress = status.requiredResourceCount > 0
          ? status.completedResourceCount / status.requiredResourceCount
          : 0.0;

      setState(() => _progress = progress);

      if (status.downloadState == OfflineRegionDownloadState.complete) {
        print('Download complete! Region ID: ${region.id}');
      }
    },
  );
}
```

`downloadOfflineRegion` returns an `OfflineRegion` object with the assigned `id`. Store this ID if you need to delete the region later.

!!! note "Re-downloading the same area"
    Downloading a region whose area (bounds, zoom range and style) matches an
    already-downloaded one replaces the existing region instead of creating a
    duplicate. The returned `id` refers to the freshly created region.

## Step 3: Track progress in UI

```dart
double _progress = 0.0;
bool _isDownloading = false;

// In your build():
if (_isDownloading)
  LinearProgressIndicator(value: _progress)
else
  ElevatedButton(
    onPressed: _startDownload,
    child: const Text('Download for offline'),
  )
```

### `OfflineRegionStatus` fields

| Field | Description |
|---|---|
| `completedResourceCount` | Tiles + assets downloaded so far |
| `requiredResourceCount` | Total tiles + assets needed |
| `completedResourceSize` | Bytes downloaded |
| `downloadState` | `active`, `complete`, or `inactive` |

Progress percentage: `completedResourceCount / requiredResourceCount * 100`

## List downloaded regions

```dart
final List<OfflineRegion> regions = await getListOfRegions();

for (final region in regions) {
  print('Region ${region.id}: ${region.metadata}');
  print('  Bounds: ${region.definition.bounds}');
  print('  Zooms: ${region.definition.minZoom} - ${region.definition.maxZoom}');
}
```

Use this to show users what they've downloaded and offer delete options.

## Check region status

```dart
final status = await getOfflineRegionStatus(region.id);
print('Downloaded: ${status.completedResourceCount} tiles');
print('Complete: ${status.downloadState == OfflineRegionDownloadState.complete}');
```

## Delete a region

```dart
await deleteOfflineRegion(region.id);
```

Frees the storage on device. If the user goes offline after deletion, those tiles are no longer available.

## Move regions between devices

Offline regions live in a single SQLite database on the device. You can copy that
database to another device and merge its regions into the local store, so a region
downloaded once can be reused elsewhere without downloading again.

```mermaid
flowchart LR
    A["Device A<br/>download regions"] --> EXP["exportOfflineDatabase(path)<br/>share the .db"]
    EXP --> FILE[(".db file")]
    FILE --> MRG["Device B<br/>mergeOfflineRegions(path)"]
    MRG --> B["Device B<br/>regions available offline"]

    classDef root fill:#1f6feb,stroke:#1a5fd0,color:#fff;
    class A,B root
```

### Export the database

`exportOfflineDatabase(destinationPath)` writes a copy of the offline database
to a location **you** choose. You pass the full destination file path (folder +
file name); the function writes the copy there and returns that same path — or
`null` if nothing has been downloaded yet. It also copies the SQLite
`-wal`/`-shm` sidecars, so the exported file is consistent.

```dart
import 'package:path_provider/path_provider.dart';

Future<String?> exportForSharing() async {
  if (kIsWeb) return null; // offline not supported on web

  final tmp = await getTemporaryDirectory();
  // You decide where the copy goes — here, a temp file called offline_export.db.
  final savedPath = await exportOfflineDatabase('${tmp.path}/offline_export.db');
  // savedPath == '${tmp.path}/offline_export.db', or null if nothing downloaded.
  return savedPath;
}
```

Then hand `savedPath` to a share sheet, upload it, or copy it elsewhere.

If you only need the live database's location (for example to copy it yourself),
use `getOfflineDatabasePath()`, which returns its absolute path or `null`.

!!! warning "Whole-database export"
    The native SDKs expose no per-region export, so the file contains **every**
    region plus the ambient cache — not a single selected region. For the same
    reason, copy the file while no download is in progress to avoid capturing a
    half-written database.

### Merge a database

`mergeOfflineRegions(path)` imports every region contained in an external database
into the local store and returns the merged regions.

```dart
Future<void> importOfflineDatabase(String path) async {
  if (kIsWeb) return; // offline not supported on web

  final List<OfflineRegion> merged = await mergeOfflineRegions(path);
  print('Merged ${merged.length} region(s)');
}
```

Databases produced by external tools (for example maplibre-native's `offline.cpp`)
can also be merged; regions without Flutter-assigned metadata are imported with an
empty metadata map and a stable, derived ID.

## Complete example pattern

```dart
class OfflineDownloadManager {
  OfflineRegion? _region;
  double _progress = 0.0;

  Future<void> startDownload(LatLngBounds bounds) async {
    if (kIsWeb) return;

    final definition = OfflineRegionDefinition(
      bounds: bounds,
      minZoom: 10,
      maxZoom: 15,
      mapStyleUrl: MapLibreStyles.openfreemapLiberty,
    );

    _region = await downloadOfflineRegion(
      definition,
      onEvent: (status) {
        _progress = status.requiredResourceCount > 0
            ? status.completedResourceCount / status.requiredResourceCount
            : 0.0;
        notifyListeners(); // or setState
      },
    );
  }

  Future<void> deleteDownload() async {
    if (_region != null) {
      await deleteOfflineRegion(_region!.id);
      _region = null;
    }
  }

  /// Export the whole offline store to the given path, e.g. to share it.
  /// Returns the written path, or null if nothing is downloaded.
  Future<String?> exportDatabase(String destinationPath) async {
    if (kIsWeb) return null;
    return exportOfflineDatabase(destinationPath);
  }

  /// Import regions from a database file exported on another device.
  Future<void> importDatabase(String path) async {
    if (kIsWeb) return;
    final imported = await mergeOfflineRegions(path);
    debugPrint('Imported ${imported.length} region(s)');
  }
}
```

## Storage considerations

- Tiles are stored in MapLibre's SQLite database on device
- iOS: stored in the app's Library/Caches (may be cleared by the OS under low storage)
- Android: stored in the app's internal storage
- Maximum tile count per region: 6,000 tiles by default (configurable at the native SDK level)
- Typical sizes: city center at zoom 10–15 ≈ 20–100 MB

!!! note "Style assets"
    The offline download includes tiles, fonts, and sprites needed by the style URL. If you later change the style URL, previously downloaded regions may not display correctly.

## Key APIs

| Function | Description |
|---|---|
| `downloadOfflineRegion(definition, onEvent)` | Start a download, get status callbacks |
| `getListOfRegions()` | List all downloaded regions |
| `getOfflineRegionStatus(id)` | Check status of a specific region |
| `deleteOfflineRegion(id)` | Delete a downloaded region |
| `mergeOfflineRegions(path)` | Import regions from an external database file |
| `exportOfflineDatabase(destPath)` | Copy the whole offline database to a shareable file |
| `getOfflineDatabasePath()` | Absolute path of the live offline database file |
