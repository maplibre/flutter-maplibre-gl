import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;

/// The package's native shim (`cpp/shim.c`), opened once per isolate.
///
/// Three consumers reach into the shim — the vsync pulse bindings, the
/// monotonic clock reader, and the display render service — and this is
/// their single probe point: one open, one log when the library is missing,
/// the same handle for everyone. Each consumer still checks for its own
/// symbols (a stale build can carry some and not others) and logs its own
/// fallback.
///
/// Opened by soname: `System.loadLibrary` already loaded the shim, so dlopen
/// returns the existing handle (`DynamicLibrary.process()` is not guaranteed
/// to see RTLD_LOCAL symbols on Android). Null off Android, or when the shim
/// cannot be opened (logged here, once); consumers then fall back per their
/// own policies.
final DynamicLibrary? shimLibrary = _open();

DynamicLibrary? _open() {
  if (!Platform.isAndroid) return null;
  try {
    return DynamicLibrary.open('libmaplibre_gl_native_shim.so');
  } catch (error) {
    debugPrint(
      '[maplibre_gl_native] shim library unavailable ($error); vsync pulses, '
      'the shim clock, and the display render service are all off',
    );
    return null;
  }
}
