// ignore_for_file: unnecessary_getters_setters

part of maplibre_gl_platform_interface;

class MethodChannelMaplibre extends MapLibreGlPlatform {
  @override
  Future<void> addCircleLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      filter,
      required bool enableInteraction}) {
    // TODO: implement addCircleLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addFillExtrusionLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      filter,
      required bool enableInteraction}) {
    // TODO: implement addFillExtrusionLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addFillLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      filter,
      required bool enableInteraction}) {
    // TODO: implement addFillLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson,
      {String? promoteId}) {
    // TODO: implement addGeoJsonSource
    throw UnimplementedError();
  }

  @override
  Future<void> addHeatmapLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) {
    // TODO: implement addHeatmapLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addHillshadeLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) {
    // TODO: implement addHillshadeLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) {
    // TODO: implement addImage
    throw UnimplementedError();
  }

  @override
  Future<void> addImageSource(
      String imageSourceId, Uint8List bytes, LatLngQuad coordinates) {
    // TODO: implement addImageSource
    throw UnimplementedError();
  }

  @override
  Future<void> addLayer(String imageLayerId, String imageSourceId,
      double? minzoom, double? maxzoom) {
    // TODO: implement addLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addLayerBelow(String imageLayerId, String imageSourceId,
      String belowLayerId, double? minzoom, double? maxzoom) {
    // TODO: implement addLayerBelow
    throw UnimplementedError();
  }

  @override
  Future<void> addLineLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      filter,
      required bool enableInteraction}) {
    // TODO: implement addLineLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addRasterLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) {
    // TODO: implement addRasterLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) {
    // TODO: implement addSource
    throw UnimplementedError();
  }

  @override
  Future<void> addSymbolLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      filter,
      required bool enableInteraction}) {
    // TODO: implement addSymbolLayer
    throw UnimplementedError();
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) {
    // TODO: implement animateCamera
    throw UnimplementedError();
  }

  @override
  Widget buildView(
      Map<String, dynamic> creationParams,
      OnPlatformViewCreatedCallback onPlatformViewCreated,
      Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers) {
    // TODO: implement buildView
    throw UnimplementedError();
  }

  @override
  void forceResizeWebMap() {
    // TODO: implement forceResizeWebMap
  }

  @override
  Future getFilter(String layerId) {
    // TODO: implement getFilter
    throw UnimplementedError();
  }

  @override
  Future<List> getLayerIds() {
    // TODO: implement getLayerIds
    throw UnimplementedError();
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) {
    // TODO: implement getMetersPerPixelAtLatitude
    throw UnimplementedError();
  }

  @override
  Future<List> getSourceIds() {
    // TODO: implement getSourceIds
    throw UnimplementedError();
  }

  @override
  Future<bool> getTelemetryEnabled() {
    // TODO: implement getTelemetryEnabled
    throw UnimplementedError();
  }

  @override
  Future<LatLngBounds> getVisibleRegion() {
    // TODO: implement getVisibleRegion
    throw UnimplementedError();
  }

  @override
  Future<void> initPlatform(int id) {
    // TODO: implement initPlatform
    throw UnimplementedError();
  }

  @override
  Future invalidateAmbientCache() {
    // TODO: implement invalidateAmbientCache
    throw UnimplementedError();
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() {
    // TODO: implement matchMapLanguageWithDeviceDefault
    throw UnimplementedError();
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) {
    // TODO: implement moveCamera
    throw UnimplementedError();
  }

  @override
  Future<List> queryRenderedFeatures(
      Point<double> point, List<String> layerIds, List<Object>? filter) {
    // TODO: implement queryRenderedFeatures
    throw UnimplementedError();
  }

  @override
  Future<List> queryRenderedFeaturesInRect(
      Rect rect, List<String> layerIds, String? filter) {
    // TODO: implement queryRenderedFeaturesInRect
    throw UnimplementedError();
  }

  @override
  Future<List> querySourceFeatures(
      String sourceId, String? sourceLayerId, List<Object>? filter) {
    // TODO: implement querySourceFeatures
    throw UnimplementedError();
  }

  @override
  Future<void> removeLayer(String imageLayerId) {
    // TODO: implement removeLayer
    throw UnimplementedError();
  }

  @override
  Future<void> removeSource(String sourceId) {
    // TODO: implement removeSource
    throw UnimplementedError();
  }

  @override
  Future<LatLng?> requestMyLocationLatLng() {
    // TODO: implement requestMyLocationLatLng
    throw UnimplementedError();
  }

  @override
  void resizeWebMap() {
    // TODO: implement resizeWebMap
  }

  @override
  Future<void> setCameraBounds(
      {required double west,
      required double north,
      required double south,
      required double east,
      required int padding}) {
    // TODO: implement setCameraBounds
    throw UnimplementedError();
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
      String sourceId, Map<String, dynamic> geojsonFeature) {
    // TODO: implement setFeatureForGeoJsonSource
    throw UnimplementedError();
  }

  @override
  Future<void> setFilter(String layerId, filter) {
    // TODO: implement setFilter
    throw UnimplementedError();
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    // TODO: implement setGeoJsonSource
    throw UnimplementedError();
  }

  @override
  Future<void> setLayerProperties(
      String layerId, Map<String, dynamic> properties) {
    // TODO: implement setLayerProperties
    throw UnimplementedError();
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) {
    // TODO: implement setLayerVisibility
    throw UnimplementedError();
  }

  @override
  Future<void> setMapLanguage(String language) {
    // TODO: implement setMapLanguage
    throw UnimplementedError();
  }

  @override
  Future<void> setTelemetryEnabled(bool enabled) {
    // TODO: implement setTelemetryEnabled
    throw UnimplementedError();
  }

  @override
  Future<LatLng> toLatLng(Point<num> screenLocation) {
    // TODO: implement toLatLng
    throw UnimplementedError();
  }

  @override
  Future<Point<num>> toScreenLocation(LatLng latLng) {
    // TODO: implement toScreenLocation
    throw UnimplementedError();
  }

  @override
  Future<List<Point<num>>> toScreenLocationBatch(Iterable<LatLng> latLngs) {
    // TODO: implement toScreenLocationBatch
    throw UnimplementedError();
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) {
    // TODO: implement updateContentInsets
    throw UnimplementedError();
  }

  @override
  Future<void> updateImageSource(
      String imageSourceId, Uint8List? bytes, LatLngQuad? coordinates) {
    // TODO: implement updateImageSource
    throw UnimplementedError();
  }

  @override
  Future<CameraPosition?> updateMapOptions(Map<String, dynamic> optionsUpdate) {
    // TODO: implement updateMapOptions
    throw UnimplementedError();
  }

  @override
  Future<void> updateMyLocationTrackingMode(
      MyLocationTrackingMode myLocationTrackingMode) {
    // TODO: implement updateMyLocationTrackingMode
    throw UnimplementedError();
  }
}
