part of maplibre_gl_mobile;

class MapLibreIos extends _MapLibreMobile {
  static void registerWith() {
    MapLibreGlPlatform.instance = MapLibreIos();
  }

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    return UiKitView(
      viewType: 'plugins.flutter.io/maplibre_gl_ios',
      onPlatformViewCreated: onPlatformViewCreated,
      gestureRecognizers: gestureRecognizers,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  @override
  Future<void> initPlatform(int id) async {
    _channel = MethodChannel('plugins.flutter.io/maplibre_gl_ios_$id');
    _channel.setMethodCallHandler(_handleMethodCall);
    await _channel.invokeMethod('map#waitForMap');
  }
}
