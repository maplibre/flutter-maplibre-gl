/// EXPERIMENTAL: maplibre_gl backend built on the MapLibre Native C API via
/// dart:ffi, rendering into a Flutter `Texture` instead of a platform view.
///
/// This package is the Android implementation of the "same API, new engine"
/// plan. Activate it before `runApp`:
///
/// ```dart
/// import 'package:maplibre_gl_native/maplibre_gl_native.dart';
///
/// void main() {
///   MapLibreGlNative.use();
///   runApp(const MyApp());
/// }
/// ```
///
/// These two types are the whole public surface: everything else (the message
/// protocol, the engine host, the platform adapter, the widgets) is an
/// implementation detail of the backend and stays under `src/`. An app keeps
/// talking to the map through maplibre_gl's own API, which is the point of the
/// package; ARCHITECTURE.md states the rule.
library;

export 'src/api/maplibre_gl_native.dart' show MapLibreGlNative;
export 'src/api/offline_api.dart' show MapLibreGlNativeOffline;
