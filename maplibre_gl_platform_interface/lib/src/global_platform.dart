part of '../maplibre_gl_platform_interface.dart';

/// Platform hooks for operations that are global to the plugin rather than
/// tied to a single map, so they can run before any map widget exists.
///
/// [MapLibrePlatform] is created per map widget through
/// [MapLibrePlatform.createInstance], which makes it unusable for calls apps
/// issue from `main()`, before the first map is built. This class fills that
/// gap: the web package replaces [instance] when it registers, the same way
/// it replaces [MapLibrePlatform.createInstance], while Android and iOS keep
/// the method-channel default.
abstract class MapLibreGlobalPlatform {
  /// The instance behind the global functions in `maplibre_gl`, such as
  /// `preWarm()` and `ensureWebLibraryLoaded()`.
  ///
  /// Defaults to [MapLibreGlobalMethodChannel]. Platform packages replace it
  /// when they register themselves.
  static MapLibreGlobalPlatform instance = MapLibreGlobalMethodChannel();

  /// Starts up the underlying map engine ahead of the first map widget.
  Future<void> preWarm();

  /// Completes once the underlying map library is ready to be called.
  ///
  /// Only web does real work here, where MapLibre GL JS is fetched at
  /// runtime; Android and iOS complete immediately because their engine is
  /// linked into the app binary. See the app-facing `ensureWebLibraryLoaded()`
  /// in `maplibre_gl`.
  Future<void> ensureLibraryLoaded();
}

/// The default [MapLibreGlobalPlatform], talking to Android and iOS over the
/// plugin's global method channel.
class MapLibreGlobalMethodChannel extends MapLibreGlobalPlatform {
  static const _channel = MethodChannel('plugins.flutter.io/maplibre_gl');

  @override
  Future<void> preWarm() async {
    try {
      await _channel.invokeMethod('preWarm');
    } on MissingPluginException {
      // Platform doesn't implement preWarm; no-op.
    }
  }

  @override
  Future<void> ensureLibraryLoaded() async {
    // Nothing to load: the native SDKs ship inside the app binary. Kept a
    // completed future rather than a throw so app code can await it
    // unconditionally on every platform.
  }
}
