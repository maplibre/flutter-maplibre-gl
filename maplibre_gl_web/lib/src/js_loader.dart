import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:web/web.dart' as web;

/// The maplibre-gl-js build injected when the app has not configured a
/// [MapLibreJsSource].
///
/// Pinned exactly rather than with a caret: every `@JS` binding in this
/// package is written against one specific build, so which build ships must
/// only change together with a review of that interop, not because the CDN
/// resolved a range to something newer.
const kMapLibreJsVersion = '5.24.0';

/// Thrown when maplibre-gl-js cannot be brought onto the page, whether the
/// injected script fails or times out, or a preloaded page never provides the
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
  /// The single in-flight or completed load. Cleared on failure (see
  /// [ensureLoaded]), never on success.
  static Future<void>? _pending;

  /// Seam for tests, which run under `flutter test --platform chrome` and
  /// must not touch the network.
  @visibleForTesting
  static Future<void> Function(MapLibreJsSource source) loadResources =
      _loadResources;

  /// Restores the loader to its initial state between tests.
  @visibleForTesting
  static void debugReset() {
    _pending = null;
    loadResources = _loadResources;
  }

  /// Completes once `globalThis.maplibregl` is usable.
  ///
  /// Safe to call from anywhere, any number of times; the work runs once.
  static Future<void> ensureLoaded() {
    // Fast path: the global is already there. This covers a classic
    // `<script src>` in index.html, which has run before Flutter starts, and
    // web hot restart, where Dart statics (including [_pending]) are reset
    // while the previously injected script is still in the document.
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

    final scriptUrl =
        source.scriptUrl ??
        'https://unpkg.com/maplibre-gl@$kMapLibreJsVersion/dist/maplibre-gl.js';
    final styleUrl =
        source.scriptUrl == null
            ? 'https://unpkg.com/maplibre-gl@$kMapLibreJsVersion/dist/maplibre-gl.css'
            : source.styleUrl;

    // The stylesheet must not be fatal: it only affects how the controls and
    // the location puck look, so a blocked maplibre-gl.css must not take the
    // whole map down with it.
    if (styleUrl != null) {
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

    await _injectScript(scriptUrl).timeout(
      source.timeout,
      onTimeout: () {
        throw MapLibreJsLoaderException(
          'timed out after ${source.timeout.inSeconds}s waiting for '
          'maplibre-gl-js from $scriptUrl. This usually means a '
          'Content-Security-Policy blocks that host, or the device is '
          'offline. MapLibreMap.webLibrarySource can point the plugin at a '
          'self-hosted copy instead.',
        );
      },
    );
  }

  /// Polls for the `maplibregl` global on a page that loads the library
  /// itself ([MapLibreJsSource.preloaded]).
  static Future<void> _waitForGlobal(Duration timeout) async {
    final clock = Stopwatch()..start();
    while (!globalContext.has('maplibregl')) {
      if (clock.elapsed > timeout) {
        throw MapLibreJsLoaderException(
          'MapLibreJsSource.preloaded is configured, but no maplibregl '
          'global appeared within ${timeout.inSeconds}s. Check that the page '
          'really loads maplibre-gl-js and that its script did not fail, or '
          'leave MapLibreMap.webLibrarySource unset to let the plugin load '
          'the library itself.',
        );
      }
      // A page usually provides the global from a <script type="module">,
      // which is deferred and finishes after Flutter has already started, so
      // there is no load event left to hook into; poll about once per frame.
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  static Future<void> _injectScript(String url) {
    final completer = Completer<void>();
    final script =
        web.document.createElement('script') as web.HTMLScriptElement
          // async: order relative to other scripts does not matter, the load
          // event below is what gates the first map.
          ..src = url
          ..async = true;
    script.addEventListener(
      'load',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS,
    );
    script.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            MapLibreJsLoaderException(
              'could not load maplibre-gl-js from $url. This usually means a '
              'Content-Security-Policy blocks that host, or the device is '
              'offline. MapLibreMap.webLibrarySource can point the plugin at '
              'a self-hosted copy instead.',
            ),
          );
        }
      }).toJS,
    );
    _head.appendChild(script);
    return completer.future;
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
