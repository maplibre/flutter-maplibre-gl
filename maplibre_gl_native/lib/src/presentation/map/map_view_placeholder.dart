import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

/// What the map area shows while there is no texture to display.
///
/// Two cases: the map is still bootstrapping (a plain background, one or two
/// frames), or it failed to initialize ([error] set), which for the app is
/// indistinguishable from the first unless it is said. The error is also
/// reported to `FlutterError.onError` by the view; this is the on-screen half,
/// kept to debug builds so a release app shows the background instead of a
/// diagnostic.
class MapViewPlaceholder extends StatelessWidget {
  const MapViewPlaceholder({super.key, this.error});

  /// The initialization failure, or null while the map is still coming up.
  final Object? error;

  /// Neutral dark fill: the map's own background before the first frame, so
  /// coming up does not flash against a typical basemap.
  static const backgroundColor = Color(0xFF111725);

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null || !kDebugMode) {
      return const ColoredBox(color: backgroundColor);
    }
    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'The map could not be initialized:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFB4AB),
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
