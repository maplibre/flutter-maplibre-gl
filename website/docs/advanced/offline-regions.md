# Offline Regions

Offline regions allow users to download a geographic area and use the map without internet access. The map tiles, fonts, and sprites are all stored on-device.

!!! warning "Android and iOS only, and iOS can evict"
    MapLibre GL JS (web) has no offline API, so guard all offline code with
    `if (!kIsWeb)`. On iOS the downloaded tiles live in the app's
    Library/Caches, which the system may clear under low storage, so treat a
    downloaded region as a cache and check it is still complete before relying
    on it.

## How it works

```mermaid
flowchart TD
    APP["Your app"] --> CALL["downloadOfflineRegion(<br/>definition, onEvent)"]
    CALL --> BG["MapLibre Native downloads<br/>tiles in the background"]
    BG --> EV["onEvent(status)<br/>called periodically<br/><small>completed / required count<br/>InProgress · Success · Error</small>"]
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

!!! warning "Tile count and the 6,000 tile cap"
    Tile count grows exponentially with zoom levels: a 10x10 km area at zoom 10
    to 16 can be thousands of tiles, and a region holds 6,000 by default (raise
    it with `setOfflineTileCountLimit`). Keep the bounds tight and the zoom
    range short instead of downloading a whole city at street level in one go.

## Step 2: Download with a progress callback

```dart
import 'package:flutter/foundation.dart'; // for kIsWeb

Future<void> downloadRegion() async {
  if (kIsWeb) return; // offline not supported on web

  final region = await downloadOfflineRegion(
    definition,
    metadata: {'name': 'Paris Center'}, // arbitrary metadata
    onEvent: (DownloadRegionStatus status) {
      if (status is InProgress) {
        final progress = status.requiredResourceCount > 0
            ? status.completedResourceCount / status.requiredResourceCount
            : 0.0;
        setState(() => _progress = progress);
      } else if (status is Success) {
        print('Download complete! Region ID: ${region.id}');
      } else if (status is Error) {
        print('Download failed: ${status.cause.message}');
      }
    },
  );
}
```

`onEvent` is called with a `DownloadRegionStatus`, which comes in three shapes: `InProgress` while tiles are arriving (it carries the resource counts and byte total), `Success` once the region is fully downloaded, and `Error` with the underlying `cause` if the download fails. Switch on the type rather than reading a state field.

`downloadOfflineRegion` returns an `OfflineRegion` object with the assigned `id`. Store this ID if you need to delete the region later.

!!! note "Re-downloading the same area"
    Downloading a region whose area (bounds, zoom range and style) matches an
    already-downloaded one replaces the existing region instead of creating a
    duplicate. On iOS the replacement keeps the id the previous region had; on
    Android the SDK assigns a new id when it creates the region. Read the id
    back from the returned `OfflineRegion` rather than assuming either.

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
| `completedResourceCount` | Tiles and assets downloaded so far |
| `requiredResourceCount` | Total tiles and assets needed |
| `completedResourceSize` | Bytes downloaded |
| `downloadProgress` | Percentage complete, 0 to 100 |
| `isComplete` | Whether the region has finished downloading |

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
print('Complete: ${status.isComplete}');
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
file name); the function writes the copy there and returns that same path, or
`null` if nothing has been downloaded yet. It also copies the SQLite
`-wal`/`-shm` sidecars, so the exported file is consistent.

```dart
import 'package:path_provider/path_provider.dart';

Future<String?> exportForSharing() async {
  if (kIsWeb) return null; // offline not supported on web

  final tmp = await getTemporaryDirectory();
  // You decide where the copy goes: here, a temp file called offline_export.db.
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
    region plus the ambient cache, not a single selected region. For the same
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

## Storage considerations

- Tiles are stored in MapLibre's SQLite database on device
- Android: stored in the app's internal storage
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
