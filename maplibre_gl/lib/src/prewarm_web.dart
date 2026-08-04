@JS()
import 'dart:js_interop';

/// Calls `maplibregl.prewarm()` to pre-create the Web Worker pool.
@JS('maplibregl.prewarm')
external void _maplibrePrewarm();

void webPrewarm() {
  _maplibrePrewarm();
}
