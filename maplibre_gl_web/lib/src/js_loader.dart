import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:web/web.dart' as web;

/// The maplibre-gl-js build loaded when the app has not configured a
/// [MapLibreJsSource].
///
/// Pinned exactly rather than with a caret: every `@JS` binding in this
/// package is written against one specific build, so which build ships must
/// only change together with a review of that interop, not because the CDN
/// resolved a range to something newer.
const kMapLibreJsVersion = '6.2.0';

/// Thrown when maplibre-gl-js cannot be brought onto the page, whether the
/// import fails or times out, or a preloaded page never provides the
/// `maplibregl` global.
class MapLibreJsLoaderException implements Exception {
  MapLibreJsLoaderException(this.message);

  final String message;

  @override
  String toString() => 'MapLibreJsLoaderException: $message';
}

/// Loads maplibre-gl-js into the page, honoring the app's
/// [MapLibreJsSource.configured] choice.
///
/// Everything in this package that touches the `maplibregl` global awaits
/// [ensureLoaded] first; the actual work runs once per session.
abstract final class MapLibreJsLoader {
  /// Where the library comes from when the app configures nothing.
  ///
  /// This has to stay an ESM build: [_importLibrary] imports it as a module,
  /// and maplibre-gl-js 6 ships nothing else. A test asserts the extension so a
  /// future version bump cannot quietly point this back at a classic script.
  static const defaultScriptUrl =
      'https://unpkg.com/maplibre-gl@$kMapLibreJsVersion/dist/maplibre-gl.mjs';

  /// The stylesheet that goes with [defaultScriptUrl].
  static const defaultStyleUrl =
      'https://unpkg.com/maplibre-gl@$kMapLibreJsVersion/dist/maplibre-gl.css';

  /// The tail both ways of not getting the library share.
  ///
  /// The MIME type is worth naming: a module script is refused outright when
  /// the server answers with the wrong one, which is what a self-hosted copy
  /// gets from a server that does not know `.mjs` yet.
  static const _importFailureHint =
      'A Content-Security-Policy that blocks that host, a device that is '
      'offline, or a server that does not serve .mjs as a JavaScript MIME type '
      'are the usual causes. MapLibreMap.webLibrarySource can point the plugin '
      'at a self-hosted copy instead.';

  /// The single in-flight or completed load. Cleared on failure (see
  /// [ensureLoaded]), never on success.
  static Future<void>? _pending;

  /// How many imports have failed outright this session, which is what makes
  /// the next attempt ask for a slightly different URL (see [_importLibrary]).
  static int _failedImports = 0;

  /// Stylesheet URLs already added to the document, so a retried load does not
  /// append a second copy of one that arrived the first time.
  static final _injectedStylesheets = <String>{};

  /// Seam for tests, which run under `flutter test --platform chrome` and
  /// must not touch the network.
  @visibleForTesting
  static Future<void> Function(MapLibreJsSource source) loadResources =
      _loadResources;

  /// Restores the loader to its initial state between tests.
  @visibleForTesting
  static void debugReset() {
    _pending = null;
    _failedImports = 0;
    _injectedStylesheets.clear();
    loadResources = _loadResources;
  }

  /// Completes once `globalThis.maplibregl` is usable.
  ///
  /// Safe to call from anywhere, any number of times; the work runs once.
  static Future<void> ensureLoaded() {
    // Fast path: the global is already there. This covers a classic
    // `<script src>` in index.html, which has run before Flutter starts, and
    // web hot restart, where Dart statics (including [_pending]) are reset
    // while the global a previous run published is still on the page.
    if (globalContext.has('maplibregl')) return Future<void>.value();
    return _pending ??= _load();
  }

  static Future<void> _load() async {
    final source = MapLibreJsSource.configured ?? const MapLibreJsSource.cdn();
    try {
      await loadResources(source);
    } catch (_) {
      // Clear the memo so the next map build retries: a transient network
      // error must not poison the whole session.
      _pending = null;
      rethrow;
    }
  }

  static Future<void> _loadResources(MapLibreJsSource source) async {
    if (source.preloaded) {
      return _waitForGlobal(source.timeout);
    }

    final scriptUrl = source.scriptUrl ?? defaultScriptUrl;
    final styleUrl =
        source.scriptUrl == null ? defaultStyleUrl : source.styleUrl;

    // The stylesheet must not be fatal: it only affects how the controls and
    // the location puck look, so a blocked maplibre-gl.css must not take the
    // whole map down with it.
    //
    // Injected at most once per URL. A failed import clears _pending so the
    // next map build retries, and the usual shape of that failure is a script
    // that would not load while the stylesheet did, so without this guard every
    // retry would append another identical <link> to <head>, without bound.
    if (styleUrl != null && _injectedStylesheets.add(styleUrl)) {
      unawaited(
        _injectStylesheet(styleUrl).timeout(source.timeout).catchError((
          Object error,
        ) {
          debugPrint(
            'maplibre_gl_web: could not load the maplibre-gl stylesheet '
            'from $styleUrl ($error). The map keeps working, but its '
            'controls and the location puck will look wrong.',
          );
        }),
      );
    }

    await _importLibrary(scriptUrl).timeout(
      source.timeout,
      onTimeout: () {
        throw MapLibreJsLoaderException(
          'timed out after ${source.timeout.inSeconds}s waiting for '
          'maplibre-gl-js from $scriptUrl. $_importFailureHint',
        );
      },
    );
  }

  /// Imports the library as an ES module and publishes its namespace as
  /// `globalThis.maplibregl`.
  ///
  /// maplibre-gl-js 6 ships as ES modules only and defines no global of its
  /// own, while every `@JS` binding in this package addresses `maplibregl.*`.
  /// Publishing the namespace here keeps that one assumption in one place, and
  /// keeps the global the fast path in [ensureLoaded] looks for.
  ///
  /// A retry asks for a slightly different URL, because a failed module fetch
  /// is remembered: the browser keeps a null entry for that URL in its module
  /// map, and every later import of it rejects on the spot without going to the
  /// network. Without the extra query the retry [ensureLoaded] allows would be
  /// no retry at all, and a map built while the device was offline could never
  /// recover, where the `<script>` tag this replaced simply tried again.
  static Future<void> _importLibrary(String url) async {
    final target = _failedImports == 0 ? url : _retryUrl(url, _failedImports);
    final JSObject module;
    try {
      module = await importModule(target.toJS).toDart;
    } catch (error) {
      _failedImports++;
      throw MapLibreJsLoaderException(
        'could not import maplibre-gl-js from $target ($error). '
        '$_importFailureHint',
      );
    }

    // Only publish a namespace that actually carries the library. An older,
    // non-module bundle imported this way runs fine, exports nothing, and
    // defines the global itself as a side effect, which is what an app still
    // pointing MapLibreJsSource.urls at a maplibre-gl 5 `.js` file gets.
    // Publishing that empty namespace would replace a working library with an
    // empty object and break every later call, with no error to go on.
    if (module.has('Map')) {
      globalContext['maplibregl'] = module;
      return;
    }
    if (globalContext.has('maplibregl')) return;
    throw MapLibreJsLoaderException(
      'loaded $target, but it provided no maplibre-gl-js: neither the module it '
      'returned nor globalThis.maplibregl has a Map constructor. If that URL '
      'is a self-hosted copy, check it is the ESM build (maplibre-gl.mjs).',
    );
  }

  /// The same URL, asking the browser for a fetch it has not cached a failure
  /// for. The query is inert: a relative worker URL still resolves against the
  /// path, so the library finds its own worker as before.
  static String _retryUrl(String url, int attempt) =>
      '$url${url.contains('?') ? '&' : '?'}maplibreGlRetry=$attempt';

  /// Polls for the `maplibregl` global on a page that loads the library
  /// itself ([MapLibreJsSource.preloaded]).
  ///
  /// Since maplibre-gl-js 6 is ESM only, importing it defines no global, so
  /// such a page has to publish the namespace itself. The error below says so,
  /// because otherwise the wait just looks like a hang.
  static Future<void> _waitForGlobal(Duration timeout) async {
    final clock = Stopwatch()..start();
    while (!globalContext.has('maplibregl')) {
      if (clock.elapsed > timeout) {
        throw MapLibreJsLoaderException(
          'MapLibreJsSource.preloaded is configured, but no maplibregl global '
          'appeared within ${timeout.inSeconds}s. maplibre-gl-js 6 is an ES '
          'module and defines no global on its own, so the page has to publish '
          'one: `globalThis.maplibregl = await import(".../maplibre-gl.mjs")`. '
          'Otherwise leave MapLibreMap.webLibrarySource unset and let the '
          'plugin load the library itself.',
        );
      }
      // A page usually provides the global from a <script type="module">,
      // which is deferred and finishes after Flutter has already started, so
      // there is no load event left to hook into; poll about once per frame.
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  static Future<void> _injectStylesheet(String url) {
    final completer = Completer<void>();
    final link =
        web.document.createElement('link') as web.HTMLLinkElement
          ..rel = 'stylesheet'
          ..href = url;
    link.addEventListener(
      'load',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS,
    );
    link.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            MapLibreJsLoaderException('the stylesheet failed to load'),
          );
        }
      }).toJS,
    );
    _head.appendChild(link);
    return completer.future;
  }

  /// `document.head` is nullable in package:web; by the time Flutter runs the
  /// document has long been parsed, so a missing head is a real error rather
  /// than something to work around.
  static web.HTMLHeadElement get _head {
    final head = web.document.head;
    if (head == null) {
      throw MapLibreJsLoaderException(
        'the document has no <head> to inject maplibre-gl-js into',
      );
    }
    return head;
  }
}
