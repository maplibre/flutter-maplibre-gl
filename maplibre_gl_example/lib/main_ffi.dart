import 'package:maplibre_gl_native/maplibre_gl_native.dart';

import 'main.dart' as gallery;

/// Runs the FULL example gallery on the experimental FFI engine, proving the
/// "same API, new engine" claim against every page:
///
/// ```sh
/// flutter run -t lib/main_ffi.dart
/// ```
///
/// Android arm64 only. The offline page still talks to the method-channel
/// global API; use MapLibreGlNativeOffline until the global seam PR lands.
Future<void> main() async {
  MapLibreGlNative.use(engineIsolate: false);
  await gallery.main();
}
