import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'attribution_ornament.dart';
import 'compass_ornament.dart';
import 'ornament_config.dart';
import 'scale_bar_ornament.dart';

/// The MapLibre mark: the official on-map logo (pin + wordmark) that the
/// native SDKs display bottom-left, at its native size.
class LogoOrnament extends StatelessWidget {
  const LogoOrnament({super.key});

  /// Native size of the logo asset, in logical pixels.
  static const size = Size(88, 23);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        'assets/maplibre_logo.png',
        package: 'maplibre_gl_native',
        width: size.width,
        height: size.height,
      ),
    );
  }
}

/// Every enabled ornament, pinned to its configured corner.
///
/// Expected to fill the map: put it in the map's [Stack] as a non-positioned
/// child of a `StackFit.expand` stack. Each ornament is driven by its own
/// listenable, so a camera stream repaints one ornament and never this
/// overlay or the map texture.
class OrnamentsOverlay extends StatelessWidget {
  const OrnamentsOverlay({
    super.key,
    required this.config,
    required this.bearing,
    required this.metersPerPixel,
    required this.cameraGeneration,
    required this.styleGeneration,
    required this.loadAttributions,
    required this.openUri,
    required this.onCompassTap,
  });

  /// Gap between the logo and an attribution pill sharing its corner, in
  /// logical pixels; the native SDKs lay them out side by side.
  static const _logoGap = 8.0;

  final FfiOrnamentConfig config;
  final ValueListenable<double> bearing;
  final ValueListenable<double> metersPerPixel;

  /// Bumped on camera movement: collapses the attribution pill.
  final ValueListenable<int> cameraGeneration;

  /// Bumped when a style finishes loading: refreshes the attributions.
  final ValueListenable<int> styleGeneration;

  final Future<List<String>> Function() loadAttributions;
  final Future<void> Function(String uri) openUri;
  final VoidCallback onCompassTap;

  /// Attribution placement, shifted past the logo when they share a corner.
  OrnamentPlacement get _attributionPlacement {
    final sharesCornerWithLogo =
        config.logoEnabled &&
        config.attribution.position == config.logo.position;
    return sharesCornerWithLogo
        ? config.attribution.withExtraX(LogoOrnament.size.width + _logoGap)
        : config.attribution;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (config.logoEnabled)
          _Pinned(placement: config.logo, child: const LogoOrnament()),
        if (config.attributionEnabled)
          _Pinned(
            placement: _attributionPlacement,
            child: AttributionOrnament(
              loadAttributions: loadAttributions,
              openUri: openUri,
              collapseSignal: cameraGeneration,
              refreshSignal: styleGeneration,
              iconAtStart: _attributionPlacement.position.isLeft,
            ),
          ),
        if (config.scaleBarEnabled)
          _Pinned(
            placement: config.scaleBar,
            child: ScaleBarOrnament(metersPerPixel: metersPerPixel),
          ),
        if (config.compassEnabled)
          _Pinned(
            placement: config.compass,
            child: ValueListenableBuilder<double>(
              valueListenable: bearing,
              builder: (context, bearing, _) =>
                  CompassOrnament(bearing: bearing, onTap: onCompassTap),
            ),
          ),
      ],
    );
  }
}

/// Positions [child] in the corner named by [placement].
class _Pinned extends StatelessWidget {
  const _Pinned({required this.placement, required this.child});

  final OrnamentPlacement placement;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final position = placement.position;
    final x = placement.margins[0].toDouble();
    final y = placement.margins[1].toDouble();
    return Positioned(
      left: position.isLeft ? x : null,
      right: position.isLeft ? null : x,
      top: position.isTop ? y : null,
      bottom: position.isTop ? null : y,
      child: child,
    );
  }
}
