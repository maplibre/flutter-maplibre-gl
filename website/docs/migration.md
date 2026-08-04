# Migration Guide

## Upgrading to 0.27.0

No breaking API changes, so nothing stops compiling. Android apps do need one change, described under [Android: style content](#android-style-content) below.

Update your `pubspec.yaml`:

```yaml
dependencies:
  maplibre_gl: ^0.27.0
```

Then run `flutter pub upgrade maplibre_gl`. See the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) for the full list of changes.

### Android: style content

A map on Android now survives its host activity being destroyed and recreated, whether by the "Don't keep activities" developer option, by a configuration change such as rotation, or under memory pressure. The `MapView` is rebuilt and the camera position is restored for you.

What is not restored automatically is style content: sources, layers, images and runtime style switches. Apply those inside `onStyleLoadedCallback`, which fires again after each recreation, so the content comes back with the new map:

```dart
MapLibreMapController? _controller;

MapLibreMap(
  onMapCreated: (controller) => _controller = controller,
  onStyleLoadedCallback: () async {
    // Runs on the first style load and again after every activity recreation.
    await _controller?.addGeoJsonSource('route', routeGeoJson);
    await _controller?.addLineLayer(
      'route',
      'route-line',
      const LineLayerProperties(lineColor: '#ff0000'),
    );
  },
)
```

If your app adds that content in `onMapCreated` or `initState` instead, move it into `onStyleLoadedCallback`. Without the move, the map comes back after a recreation with the base style only, and your own layers missing.

### Minimum SDK versions

Unchanged from 0.26.x.

| Platform | Minimum version |
|----------|----------------|
| Android  | API 21 (Android 5.0) |
| iOS      | iOS 12 |
| Flutter  | 3.29.0 |
| Dart     | 3.7.0 |

### Behaviour changes

None of these need a code change, but they are the places where code that worked before starts behaving differently.

* **Web**: `onMapIdle` now fires. If you worked around it never running on web, that workaround can go.
* **Web**: `queryCameraPosition()`, `updateContentInsets()` and the new `setPadding()` no longer throw `UnimplementedError`, so any guard you put around them for web is no longer needed.
* **iOS**: `mergeOfflineRegions()` returns only the regions it imported, instead of every region already stored. If you used its return value as the full list, call `getListOfRegions()` for that.
* **Android, iOS**: downloading an area that is already downloaded replaces the existing region rather than adding a duplicate, and the replacement keeps the same region id.
* **Android, iOS**: the attribution (i) button is tinted black by default instead of the SDK's blue, which was hard to read over most map backgrounds. Pass `attributionButtonColor` to `MapLibreMap` to choose your own tint, for example a light one over a dark style.

### Android apps on AGP 9

The plugin no longer applies the Kotlin Gradle Plugin when your app builds with Android Gradle Plugin 9 or later, which is what broke that build before. Apps on AGP 8 are unaffected and need no change.

## Upgrading to 0.26.2

See the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) for the full list of changes.

### Breaking changes

Check the CHANGELOG for any breaking changes introduced in 0.26.x. If you were on an earlier 0.26 release, the upgrade should be straightforward for most apps.

### Minimum SDK versions

| Platform | Minimum version |
|----------|----------------|
| Android  | API 21 (Android 5.0) |
| iOS      | iOS 12 |
| Flutter  | 3.29.0 |
| Dart     | 3.7.0 |

## Upgrading from earlier 0.26 releases

No structural changes to the public API. Run `flutter pub upgrade maplibre_gl` and check the CHANGELOG for any deprecation notices.
