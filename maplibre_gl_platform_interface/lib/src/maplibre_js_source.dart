part of '../maplibre_gl_platform_interface.dart';

/// Where the web implementation loads MapLibre GL JS from.
///
/// On web the plugin drives MapLibre GL JS through JS interop, so the library
/// has to be on the page before the first map is built. By default the plugin
/// injects the exact build it is tested against, which means `web/index.html`
/// needs no `<script>` or `<link>` tag. Apps with other constraints describe
/// theirs with one of the named constructors and assign it to
/// `MapLibreMap.webLibrarySource` before the first map is built.
///
/// This class only describes the choice; the web implementation interprets
/// it. It lives in the platform interface so app-facing code can configure it
/// without importing the web package, and it is ignored on Android and iOS,
/// where the map engine is linked into the app binary.
@immutable
class MapLibreJsSource {
  /// The build this plugin is tested against, fetched from the unpkg CDN.
  ///
  /// This is what the plugin uses when nothing is configured.
  const MapLibreJsSource.cdn({this.timeout = _defaultTimeout})
    : scriptUrl = null,
      styleUrl = null,
      preloaded = false;

  /// A self-hosted copy of MapLibre GL JS, or files shipped as web assets.
  ///
  /// For apps whose Content-Security-Policy rules out a CDN, or that cannot
  /// rely on one being reachable. [styleUrl] is optional, but without a
  /// stylesheet the map controls and the location puck lose their styling, so
  /// leave it unset only when the page provides `maplibre-gl.css` some other
  /// way.
  const MapLibreJsSource.urls({
    required String this.scriptUrl,
    this.styleUrl,
    this.timeout = _defaultTimeout,
  }) : preloaded = false;

  /// The page loads MapLibre GL JS itself; the plugin injects nothing and
  /// only waits for the `maplibregl` global to appear.
  ///
  /// This is required rather than a shortcut for such pages: a
  /// `<script type="module">` is deferred, so the global is not present yet
  /// when the first map is built, and the plugin has to wait for it instead
  /// of assuming it is there.
  const MapLibreJsSource.preloaded({this.timeout = _defaultTimeout})
    : scriptUrl = null,
      styleUrl = null,
      preloaded = true;

  static const _defaultTimeout = Duration(seconds: 20);

  /// URL of the maplibre-gl-js script to inject, or null when the plugin's
  /// pinned build is used ([MapLibreJsSource.cdn]) or nothing is injected at
  /// all ([MapLibreJsSource.preloaded]).
  final String? scriptUrl;

  /// URL of the `maplibre-gl.css` stylesheet to inject alongside [scriptUrl].
  final String? styleUrl;

  /// Whether the page loads the library itself ([MapLibreJsSource.preloaded]).
  final bool preloaded;

  /// How long the web implementation waits for the library before failing.
  final Duration timeout;

  /// The app's choice, assigned through `MapLibreMap.webLibrarySource`.
  ///
  /// Null means the default [MapLibreJsSource.cdn].
  static MapLibreJsSource? configured;

  @override
  String toString() =>
      'MapLibreJsSource('
      '${preloaded ? 'preloaded' : scriptUrl ?? 'cdn'}, '
      'timeout: $timeout)';
}
