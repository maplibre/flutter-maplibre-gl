import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Common constants used across examples
class ExampleConstants {
  ExampleConstants._();

  // ============================================================================
  // Map Coordinates
  // ============================================================================

  /// Default map center (Sydney, Australia)
  static const LatLng sydneyCenter = LatLng(-33.86711, 151.1947171);

  /// Alternative coordinates for variety
  static const LatLng sanFrancisco = LatLng(37.7749, -122.4194);
  static const LatLng london = LatLng(51.5074, -0.1278);
  static const LatLng tokyo = LatLng(35.6762, 139.6503);

  // ============================================================================
  // Map Configuration
  // ============================================================================

  /// Default zoom level
  static const double defaultZoom = 4.0;

  /// Default map bounds (Australia region)
  static final LatLngBounds defaultBounds = LatLngBounds(
    southwest: const LatLng(-34.0, 150.5),
    northeast: const LatLng(-33.5, 151.5),
  );

  // ============================================================================
  // Spacing & Layout
  // ============================================================================

  /// Standard padding for content
  static const double paddingStandard = 16.0;

  /// Small padding
  static const double paddingSmall = 8.0;

  /// Tiny padding for tight spaces
  static const double paddingTiny = 4.0;

  /// Spacing between buttons in control panels
  static const double buttonSpacing = 8.0;

  /// Run spacing for wrapped button groups
  static const double buttonRunSpacing = 8.0;

  /// Map height ratio (portion of screen height)
  static const double mapHeightRatio = 0.5;

  /// Border radius for cards and containers
  static const double borderRadius = 12.0;

  // ============================================================================
  // Map Styles
  // ============================================================================

  /// Demo map style URL (default). demotiles.maplibre.org is aggressively
  /// rate-limited (HTTP 429); [resolveDemoMapStyle] swaps in
  /// [fallbackMapStyle] when it is unreachable (probed at startup and again
  /// right before each example page opens).
  static String demoMapStyle = preferredDemoMapStyle;

  /// The canonical MapLibre demo style.
  static const String preferredDemoMapStyle =
      'https://demotiles.maplibre.org/style.json';

  /// Fallback style used when the demo style is unreachable.
  static const String fallbackMapStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Font stack that exists on the glyph server of the ACTIVE demo style.
  /// demotiles only serves "Open Sans Semibold"; OpenFreeMap only serves
  /// Noto Sans variants; neither resolves multi-font stacks. When a symbol
  /// layer's fonts 404, MapLibre Native never completes symbol layout for
  /// the tile and the symbols disappear entirely, icons included.
  static List<String> get demoFontStack =>
      demoMapStyle == preferredDemoMapStyle
          ? const ['Open Sans Semibold']
          : const ['Noto Sans Regular'];

  /// Bold variant of [demoFontStack] (e.g. cluster counts). demotiles only
  /// serves a single font, so both getters collapse there.
  static List<String> get demoBoldFontStack =>
      demoMapStyle == preferredDemoMapStyle
          ? const ['Open Sans Semibold']
          : const ['Noto Sans Bold'];

  /// Sticky flag: once the demo style probe fails we stay on
  /// [fallbackMapStyle] for the rest of the session (a limiter that just
  /// rejected us will most likely reject the map's burst of requests too).
  static bool _demoStyleFellBack = false;

  /// When the last successful probe completed, for [resolveDemoMapStyle]'s
  /// maxAge memoization.
  static DateTime? _lastSuccessfulProbe;

  /// Probes the demo style AND its tile endpoint, falling back to
  /// [fallbackMapStyle] when either fails. Probing the style alone is not
  /// enough: GitHub Pages' edge cache can serve style.json with 200 while
  /// the tile paths are already rate-limited with 429, which would render
  /// the style background with no tiles.
  ///
  /// The rate limiter answers per request (429 with retry-after: 0), so a
  /// probe that passed at startup proves nothing minutes later. Call this
  /// again right before opening a map page, passing [maxAge] to skip the
  /// network round-trip when a recent probe already succeeded. Once fallen
  /// back the choice is sticky and this returns immediately.
  static Future<void> resolveDemoMapStyle({Duration? maxAge}) async {
    if (_demoStyleFellBack) return;
    final lastSuccess = _lastSuccessfulProbe;
    if (maxAge != null &&
        lastSuccess != null &&
        DateTime.now().difference(lastSuccess) < maxAge) {
      return;
    }
    // Probe with a small CONCURRENT burst: the limiter tends to pass
    // isolated requests while rejecting bursts, and a real map load is a
    // burst of style + sprite + glyphs + tiles.
    const probes = [
      preferredDemoMapStyle,
      'https://demotiles.maplibre.org/tiles/tiles.json',
      'https://demotiles.maplibre.org/tiles/0/0/0.pbf',
    ];
    const timeout = Duration(seconds: 4);
    // package:http works on every platform, web included, where a CORS or
    // rate-limit failure surfaces as an exception and lands in the fallback.
    final client = http.Client();
    try {
      final statuses = await Future.wait(
        probes.map((url) async {
          final response = await client.get(Uri.parse(url)).timeout(timeout);
          return response.statusCode;
        }),
      );
      final failed = statuses.indexWhere((code) => code >= 400);
      if (failed != -1) {
        _demoStyleFellBack = true;
        demoMapStyle = fallbackMapStyle;
        debugPrint(
          'demo style unreachable (${probes[failed]}: '
          'HTTP ${statuses[failed]}); falling back to $fallbackMapStyle',
        );
        return;
      }
      _lastSuccessfulProbe = DateTime.now();
    } catch (error) {
      _demoStyleFellBack = true;
      demoMapStyle = fallbackMapStyle;
      debugPrint(
        'demo style unreachable ($error); falling back to $fallbackMapStyle',
      );
    } finally {
      client.close();
    }
  }

  /// Style asset paths
  static const String osmStyleAsset = 'assets/osm_style.json';
  static const String pmtilesStyleAsset = 'assets/pmtiles_style.json';
  static const String translucenStyleAsset = 'assets/translucent_style.json';
  static const String localStyleAsset = 'assets/style.json';

  // ============================================================================
  // Colors
  // ============================================================================

  /// Primary accent color for UI elements
  static const Color primaryColor = Color(0xFF1976D2);

  /// Secondary accent color
  static const Color secondaryColor = Color(0xFF388E3C);

  /// Error/destructive action color
  static const Color errorColor = Color(0xFFD32F2F);

  /// Warning color
  static const Color warningColor = Color(0xFFFFA726);

  // ============================================================================
  // Animation Durations
  // ============================================================================

  /// Standard animation duration
  static const Duration animationDuration = Duration(milliseconds: 300);

  /// Camera animation duration
  static const Duration cameraAnimationDuration = Duration(milliseconds: 1000);

  /// Long animation duration
  static const Duration longAnimationDuration = Duration(milliseconds: 2000);

  // ============================================================================
  // Camera Positions
  // ============================================================================

  /// Default camera position
  static CameraPosition defaultCameraPosition = toCameraPosition(
    const LatLng(0.0, 0.0),
  );

  /// Camera position for Sydney
  static CameraPosition sydneyCameraPosition = toCameraPosition(sydneyCenter);

  /// Camera position for San Francisco
  static CameraPosition sanFranciscoCameraPosition = toCameraPosition(
    sanFrancisco,
  );

  /// Camera position for London
  static CameraPosition londonCameraPosition = toCameraPosition(london);

  /// Camera position for Tokyo
  static CameraPosition tokyoCameraPosition = toCameraPosition(tokyo);

  /// Helper to create a CameraPosition with default zoom.
  static CameraPosition toCameraPosition(
    LatLng target, [
    double zoom = defaultZoom,
  ]) {
    return CameraPosition(target: target, zoom: zoom);
  }

  // ============================================================================
  // Map Settings
  // ============================================================================

  /// Default tilt angle
  static const double defaultTilt = 0.0;

  /// Default bearing (rotation)
  static const double defaultBearing = 0.0;

  /// Minimum zoom level
  static const double minZoom = 0.0;

  /// Maximum zoom level
  static const double maxZoom = 22.0;

  // ===========================================================================
  // Pattern images paths
  // ===========================================================================

  /// Pattern image for fill layer example
  static const String catPatternPath =
      'assets/pattern/cat_silhouette_pattern.png';

  /// Pattern image for line layer example
  static const String markerPatternPath = 'assets/pattern/marker_pattern.png';
}
