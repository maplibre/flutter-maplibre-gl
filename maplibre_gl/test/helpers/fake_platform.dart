import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

/// A call record for verifying interactions with [FakeMapLibrePlatform].
class PlatformCall {
  final String method;
  final List<dynamic> positionalArgs;
  final Map<String, dynamic> namedArgs;

  PlatformCall(
    this.method, [
    this.positionalArgs = const [],
    this.namedArgs = const {},
  ]);

  @override
  String toString() => 'PlatformCall($method, $positionalArgs, $namedArgs)';
}

/// Fake implementation of [MapLibrePlatform] that records all method calls.
class FakeMapLibrePlatform extends MapLibrePlatform {
  final calls = <PlatformCall>[];

  /// Clears recorded calls.
  void reset() => calls.clear();

  /// Returns all calls with the given method name.
  List<PlatformCall> callsFor(String method) =>
      calls.where((c) => c.method == method).toList();

  /// Whether a method was called at least once.
  bool wasCalled(String method) => calls.any((c) => c.method == method);

  @override
  Future<void> initPlatform(int id) async {
    calls.add(PlatformCall('initPlatform', [id]));
  }

  /// The last creationParams passed to [buildView].
  Map<String, dynamic>? lastCreationParams;

  /// Whether [buildView] should automatically trigger [onPlatformViewCreated].
  bool triggerPlatformViewCreated = false;

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    lastCreationParams = creationParams;
    calls.add(PlatformCall('buildView', [creationParams]));
    if (triggerPlatformViewCreated) {
      onPlatformViewCreated(0);
    }
    return const SizedBox.shrink();
  }

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    calls.add(PlatformCall('updateMapOptions', [optionsUpdate]));
    return const CameraPosition(target: LatLng(0, 0));
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    calls.add(
      PlatformCall('animateCamera', [cameraUpdate], {'duration': duration}),
    );
    return true;
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    calls.add(PlatformCall('moveCamera', [cameraUpdate]));
    return true;
  }

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async {
    calls.add(
      PlatformCall('updateMyLocationTrackingMode', [myLocationTrackingMode]),
    );
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {
    calls.add(PlatformCall('matchMapLanguageWithDeviceDefault'));
  }

  @override
  void resizeWebMap() {}

  @override
  void forceResizeWebMap() {}

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {}

  @override
  Future<void> setMapLanguage(String language) async {}

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {}

  @override
  Future<bool> getTelemetryEnabled() async => false;

  @override
  Future<void> setMaximumFps(int fps) async {}

  @override
  Future<void> forceOnlineMode() async {}

  @override
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  }) async {
    calls.add(
      PlatformCall(
        'easeCamera',
        [cameraUpdate],
        {'duration': duration, 'interpolation': interpolation},
      ),
    );
    return true;
  }

  @override
  Future<CameraPosition?> queryCameraPosition() async {
    calls.add(PlatformCall('queryCameraPosition'));
    return const CameraPosition(target: LatLng(0, 0));
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async => true;

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async => true;

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async => true;

  @override
  Future<String?> getStyle() async => null;

  @override
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) async {}

  @override
  Future<Map<String, String>> getCustomHeaders() async => {};

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async => [];

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async => [];

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async => [];

  @override
  Future invalidateAmbientCache() async {}

  @override
  Future clearAmbientCache() async {}

  @override
  Future<LatLng?> requestMyLocationLatLng() async => const LatLng(0, 0);

  @override
  Future<LatLngBounds> getVisibleRegion() async => LatLngBounds(
    southwest: const LatLng(-1, -1),
    northeast: const LatLng(1, 1),
  );

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async {}

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) async {}

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {}

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) async {
    calls.add(
      PlatformCall('addLayer', [imageLayerId, imageSourceId, minzoom, maxzoom]),
    );
  }

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) async {
    calls.add(
      PlatformCall('addLayerBelow', [
        imageLayerId,
        imageSourceId,
        belowLayerId,
      ]),
    );
  }

  @override
  Future<void> removeLayer(String layerId) async {
    calls.add(PlatformCall('removeLayer', [layerId]));
  }

  @override
  Future<List> getLayerIds() async => [];

  @override
  Future<List> getSourceIds() async => [];

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {}

  @override
  Future<dynamic> getFilter(String layerId) async => null;

  @override
  Future<Point> toScreenLocation(LatLng latLng) async => const Point(0, 0);

  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) async =>
      [];

  @override
  Future<LatLng> toLatLng(Point screenLocation) async => const LatLng(0, 0);

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async => 1.0;

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    calls.add(
      PlatformCall(
        'addGeoJsonSource',
        [sourceId, geojson],
        {'promoteId': promoteId},
      ),
    );
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    calls.add(PlatformCall('setGeoJsonSource', [sourceId, geojson]));
  }

  @override
  Future<void> setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {}

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) async {
    calls.add(
      PlatformCall('setFeatureForGeoJsonSource', [sourceId, geojsonFeature]),
    );
  }

  @override
  Future<void> setFeatureState(
    String sourceId,
    String featureId,
    Map<String, dynamic> state, {
    String? sourceLayer,
  }) async {}

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) async {}

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) async => null;

  @override
  Future<void> removeSource(String sourceId) async {
    calls.add(PlatformCall('removeSource', [sourceId]));
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    calls.add(PlatformCall('addSymbolLayer', [sourceId, layerId, properties]));
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    calls.add(PlatformCall('addLineLayer', [sourceId, layerId, properties]));
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    calls.add(PlatformCall('setLayerProperties', [layerId, properties]));
  }

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    calls.add(PlatformCall('addCircleLayer', [sourceId, layerId, properties]));
  }

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    calls.add(PlatformCall('addFillLayer', [sourceId, layerId, properties]));
  }

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    calls.add(
      PlatformCall('addFillExtrusionLayer', [sourceId, layerId, properties]),
    );
  }

  @override
  Future<void> addRasterLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    calls.add(PlatformCall('addRasterLayer', [sourceId, layerId, properties]));
  }

  @override
  Future<void> addHillshadeLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    calls.add(
      PlatformCall('addHillshadeLayer', [sourceId, layerId, properties]),
    );
  }

  @override
  Future<void> addHeatmapLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    calls.add(PlatformCall('addHeatmapLayer', [sourceId, layerId, properties]));
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    calls.add(PlatformCall('addSource', [sourceId, properties]));
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    calls.add(PlatformCall('setLayerVisibility', [layerId, visible]));
  }

  @override
  Future<bool?> getLayerVisibility(String layerId) async => true;

  @override
  Future<Size> setWebMapToCustomSize(Size size) async => size;

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() async {}

  @override
  Future<void> waitUntilMapTilesAreLoaded() async {}

  /// Fake PNG bytes returned by [takeSnapshot].
  Uint8List snapshotResult = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) async {
    calls.add(
      PlatformCall('takeSnapshot', [], {'width': width, 'height': height}),
    );
    return snapshotResult;
  }

  @override
  Future<void> setStyle(String styleString) async {
    calls.add(PlatformCall('setStyle', [styleString]));
  }
}
