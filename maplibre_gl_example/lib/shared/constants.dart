import 'package:flutter/material.dart';
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

  /// Demo map style URL (default)
  static const String demoMapStyle =
      'https://demotiles.maplibre.org/style.json';

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
  static CameraPosition sanFranciscoCameraPosition =
      toCameraPosition(sanFrancisco);

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
