# Migration Guide

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

No structural changes to the public API. Update your `pubspec.yaml`:

```yaml
dependencies:
  maplibre_gl: ^0.26.2
```

Run `flutter pub upgrade maplibre_gl` and check the CHANGELOG for any deprecation notices.
