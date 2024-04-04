part of maplibre_gl_mobile;

class MapLibreAndroid extends _MapLibreMobile {
  static void registerWith() {
    MapLibreGlPlatform.instance = MapLibreAndroid();
  }

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    return AndroidView(
      viewType: 'plugins.flutter.io/maplibre_gl_android',
      onPlatformViewCreated: onPlatformViewCreated,
      gestureRecognizers: gestureRecognizers,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  @override
  Future<void> initPlatform(int id) async {
    _channel = MethodChannel('plugins.flutter.io/maplibre_gl_android_$id');
    _channel.setMethodCallHandler(_handleMethodCall);
    await _channel.invokeMethod('map#waitForMap');
  }
}
