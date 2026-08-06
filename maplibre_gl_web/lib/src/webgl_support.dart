import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Whether this browser hands out the WebGL context [version2] asks for.
///
/// Probes a throwaway canvas and drops the context again: a page may only hold
/// a handful of live WebGL contexts, and a probe must not spend one of them.
/// Only reached once a map has already come up without a renderer, so a working
/// map never pays for it.
bool canCreateWebGlContext({required bool version2}) {
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
  final context = canvas.getContext(version2 ? 'webgl2' : 'webgl');
  if (context == null) return false;
  // WEBGL_lose_context is optional. Without it the context goes away with the
  // canvas, one garbage collection later.
  context
      .callMethod<JSObject?>('getExtension'.toJS, 'WEBGL_lose_context'.toJS)
      ?.callMethod<JSAny?>('loseContext'.toJS);
  return true;
}

/// What to report for a map that came up without a renderer, or null when the
/// map is fine or WebGL is not the reason.
///
/// maplibre-gl-js 6 draws with WebGL2 and dropped the WebGL1 fallback that 5
/// had. It also stopped throwing when it cannot get a context: it fires an
/// `error` while the map is still inside its constructor, before this package
/// could subscribe to anything, and then leaves the map without a renderer. So
/// the renderer is read back afterwards instead, and [probe] tells the two
/// causes apart, since only one of them has a way out.
String? webGlDiagnostic({
  required bool hasRenderer,
  required bool Function({required bool version2}) probe,
}) {
  if (hasRenderer) return null;
  if (probe(version2: true)) return null;
  if (!probe(version2: false)) {
    return 'maplibre_gl_web: the map has no renderer, because this browser '
        'provides no WebGL context at all. No build of maplibre-gl-js can draw '
        'here: usually hardware acceleration is switched off, or the GPU or its '
        'driver is on the browser blocklist.';
  }
  return 'maplibre_gl_web: the map has no renderer, because this browser has '
      'WebGL1 but not WebGL2. maplibre-gl-js 6 requires WebGL2 and dropped the '
      'WebGL1 fallback that 5 had. To keep browsers like this one, point '
      'MapLibreMap.webLibrarySource at a maplibre-gl-js 5 build, the last major '
      'with that fallback: '
      'https://maplibre.org/flutter-maplibre-gl/migration/#web-the-engine-moves-to-maplibre-gl-js-6';
}
