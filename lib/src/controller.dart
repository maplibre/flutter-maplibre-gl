// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of maplibre_gl;

typedef void OnMapClickCallback(Point<double> point, LatLng coordinates);

typedef void OnFeatureInteractionCallback(
    dynamic id, Point<double> point, LatLng coordinates);

typedef void OnFeatureDragnCallback(dynamic id,
    {required Point<double> point,
    required LatLng origin,
    required LatLng current,
    required LatLng delta,
    required DragEventType eventType});

typedef void OnMapLongClickCallback(Point<double> point, LatLng coordinates);

typedef void OnStyleLoadedCallback();

typedef void OnUserLocationUpdated(UserLocation location);

typedef void OnCameraTrackingDismissedCallback();
typedef void OnCameraTrackingChangedCallback(MyLocationTrackingMode mode);

typedef void OnCameraIdleCallback();

typedef void OnMapIdleCallback();

/// Controller for a single [MaplibreMap] instance running on the host platform.
///
/// Some of its methods can only be called after the [onStyleLoaded] callback has been invoked.
///
/// To add annotations ([Circle]s, [Line]s, [Symbol]s and [Fill]s) on the map, there are two ways:
///
/// 1. *Simple way to add annotations*: Use the corresponding add* methods ([addCircle], [addLine], [addSymbol] and [addFill]) on the MaplibreMapController to add one annotation at a time to the map.
/// There are also corresponding [addCircles], [addLines] etc. methods which work the same but add multiple annotations at a time.
///
/// (If you are interested how this works: under the hood, this uses AnnotationManagers to manage the annotations.
/// An annotation manager performs the steps from the advanced way, but hides the complexity from the developer.
/// E.g. the [addCircle] method uses the [CircleManager], which in turn adds a GeoJson source to the map's style with the circle's locations as features.
/// The CircleManager also adds a circle style layer to the map's style that references that GeoJson source, therefore rendering all circles added with [addCircle] on the map.)
///
/// There are also corresponding clear* methods like [clearCircles] to remove all circles from the map, which had been added with [addCircle] or [addCircles].
///
/// There are also properties like [circles] to get the current set of circles on the map, which had been added with [addCircle] or [addCircles].
///
/// Click events on annotations that are added this way (with the [addCircle], [addLine] etc. methods) can be received by adding callbacks to [onCircleTapped], [onLineTapped] etc.
///
/// Note: [circles], [clearCircles] and [onCircleTapped] only work for circles added with [addCircle] or [addCircles],
/// not for circles that are already contained in the map's style when the map is loaded or are added to that map's style with the methods from the advanced way (see below).
/// The same of course applies for fills, lines and symbols.
///
/// 2. *Advanced way to add annotations*: Modify the underlying Maplibre Style of the map to add a new data source (e.g. with the [addSource] method or the more specific methods like [addGeoJsonSource])
/// and add a new layer to display the data of that source on the map (either with the [addLayer] method or with the more specific methods like [addCircleLayer], [addLineLayer] etc.).
/// For more information about Maplibre Styles, see the documentation of [maplibre_gl] as well as the specification at [https://maplibre.org/maplibre-style-spec/].
///
/// A MaplibreMapController is also a [ChangeNotifier]. Subscribers (change listeners) are notified upon changes to any of
///
/// * the configuration options of the [MaplibreMap] widget
/// * the [symbols], [lines], [circles] or [fills] properties
/// (i.e. the collection of [Symbol]s, [Line]s, [Circle]s and [Fill]s added to this map via the "simple way" (see above))
/// * the [isCameraMoving] property
/// * the [cameraPosition] property
///
/// Listeners are notified after changes have been applied on the platform side.
class MaplibreMapController extends ChangeNotifier {
  MaplibreMapController({
    required MapLibreGlPlatform maplibreGlPlatform,
    required CameraPosition initialCameraPosition,
    required Iterable<AnnotationType> annotationOrder,
    required Iterable<AnnotationType> annotationConsumeTapEvents,
    this.onStyleLoadedCallback,
    this.onMapClick,
    this.onMapLongClick,
    //this.onAttributionClick,
    this.onCameraTrackingDismissed,
    this.onCameraTrackingChanged,
    this.onMapIdle,
    this.onUserLocationUpdated,
    this.onCameraIdle,
  }) : _maplibreGlPlatform = maplibreGlPlatform {
    _cameraPosition = initialCameraPosition;

    _maplibreGlPlatform.onFeatureTappedPlatform.add((payload) {
      for (final fun
          in List<OnFeatureInteractionCallback>.from(onFeatureTapped)) {
        fun(payload["id"], payload["point"], payload["latLng"]);
      }
    });

    _maplibreGlPlatform.onFeatureDraggedPlatform.add((payload) {
      for (final fun in List<OnFeatureDragnCallback>.from(onFeatureDrag)) {
        final DragEventType enmDragEventType = DragEventType.values
            .firstWhere((element) => element.name == payload["eventType"]);
        fun(payload["id"],
            point: payload["point"],
            origin: payload["origin"],
            current: payload["current"],
            delta: payload["delta"],
            eventType: enmDragEventType);
      }
    });

    _maplibreGlPlatform.onCameraMoveStartedPlatform.add((_) {
      _isCameraMoving = true;
      notifyListeners();
    });

    _maplibreGlPlatform.onCameraMovePlatform.add((cameraPosition) {
      _cameraPosition = cameraPosition;
      notifyListeners();
    });

    _maplibreGlPlatform.onCameraIdlePlatform.add((cameraPosition) {
      _isCameraMoving = false;
      if (cameraPosition != null) {
        _cameraPosition = cameraPosition;
      }
      if (onCameraIdle != null) {
        onCameraIdle!();
      }
      notifyListeners();
    });

    _maplibreGlPlatform.onMapStyleLoadedPlatform.add((_) {
      final interactionEnabled = annotationConsumeTapEvents.toSet();
      for (var type in annotationOrder.toSet()) {
        final enableInteraction = interactionEnabled.contains(type);
        switch (type) {
          case AnnotationType.fill:
            fillManager = FillManager(this,
                onTap: onFillTapped, enableInteraction: enableInteraction);
            break;
          case AnnotationType.line:
            lineManager = LineManager(this,
                onTap: onLineTapped, enableInteraction: enableInteraction);
            break;
          case AnnotationType.circle:
            circleManager = CircleManager(this,
                onTap: onCircleTapped, enableInteraction: enableInteraction);
            break;
          case AnnotationType.symbol:
            symbolManager = SymbolManager(this,
                onTap: onSymbolTapped, enableInteraction: enableInteraction);
            break;
          default:
        }
      }
      if (onStyleLoadedCallback != null) {
        onStyleLoadedCallback!();
      }
    });

    _maplibreGlPlatform.onMapClickPlatform.add((dict) {
      if (onMapClick != null) {
        onMapClick!(dict['point'], dict['latLng']);
      }
    });

    _maplibreGlPlatform.onMapLongClickPlatform.add((dict) {
      if (onMapLongClick != null) {
        onMapLongClick!(dict['point'], dict['latLng']);
      }
    });

    _maplibreGlPlatform.onCameraTrackingChangedPlatform.add((mode) {
      if (onCameraTrackingChanged != null) {
        onCameraTrackingChanged!(mode);
      }
    });

    _maplibreGlPlatform.onCameraTrackingDismissedPlatform.add((_) {
      if (onCameraTrackingDismissed != null) {
        onCameraTrackingDismissed!();
      }
    });

    _maplibreGlPlatform.onMapIdlePlatform.add((_) {
      if (onMapIdle != null) {
        onMapIdle!();
      }
    });
    _maplibreGlPlatform.onUserLocationUpdatedPlatform.add((location) {
      onUserLocationUpdated?.call(location);
    });
  }

  FillManager? fillManager;
  LineManager? lineManager;
  CircleManager? circleManager;
  SymbolManager? symbolManager;

  final OnStyleLoadedCallback? onStyleLoadedCallback;
  final OnMapClickCallback? onMapClick;
  final OnMapLongClickCallback? onMapLongClick;

  final OnUserLocationUpdated? onUserLocationUpdated;

  final OnCameraTrackingDismissedCallback? onCameraTrackingDismissed;
  final OnCameraTrackingChangedCallback? onCameraTrackingChanged;

  final OnCameraIdleCallback? onCameraIdle;

  final OnMapIdleCallback? onMapIdle;

  /// Callbacks to receive tap events for symbols placed on this map.
  final ArgumentCallbacks<Symbol> onSymbolTapped = ArgumentCallbacks<Symbol>();

  /// Callbacks to receive tap events for symbols placed on this map.
  final ArgumentCallbacks<Circle> onCircleTapped = ArgumentCallbacks<Circle>();

  /// Callbacks to receive tap events for fills placed on this map.
  final ArgumentCallbacks<Fill> onFillTapped = ArgumentCallbacks<Fill>();

  /// Callbacks to receive tap events for features (geojson layer) placed on this map.
  final onFeatureTapped = <OnFeatureInteractionCallback>[];

  final onFeatureDrag = <OnFeatureDragnCallback>[];

  /// Callbacks to receive tap events for info windows on symbols
  @Deprecated("InfoWindow tapped is no longer supported")
  final ArgumentCallbacks<Symbol> onInfoWindowTapped =
      ArgumentCallbacks<Symbol>();

  /// The current set of symbols on this map added with the [addSymbol] or [addSymbols] methods.
  ///
  /// The returned set will be a detached snapshot of the symbols collection.
  Set<Symbol> get symbols => symbolManager!.annotations;

  /// Callbacks to receive tap events for lines placed on this map.
  final ArgumentCallbacks<Line> onLineTapped = ArgumentCallbacks<Line>();

  /// The current set of lines on this map added with the [addLine] or [addLines] methods.
  ///
  /// The returned set will be a detached snapshot of the lines collection.
  Set<Line> get lines => lineManager!.annotations;

  /// The current set of circles on this map added with the [addCircle] or [addCircles] methods.
  ///
  /// The returned set will be a detached snapshot of the circles collection.
  Set<Circle> get circles => circleManager!.annotations;

  /// The current set of fills on this map added with the [addFill] or [addFills] methods.
  ///
  /// The returned set will be a detached snapshot of the fills collection.
  Set<Fill> get fills => fillManager!.annotations;

  /// True if the map camera is currently moving.
  bool get isCameraMoving => _isCameraMoving;
  bool _isCameraMoving = false;

  /// Returns the most recent camera position reported by the platform side.
  /// Will be null, if [MaplibreMap.trackCameraPosition] is false.
  CameraPosition? get cameraPosition => _cameraPosition;
  CameraPosition? _cameraPosition;

  final MapLibreGlPlatform _maplibreGlPlatform; //ignore: unused_field

  /// Updates configuration options of the map user interface.
  ///
  /// Change listeners are notified once the update has been made on the
  /// platform side.
  ///
  /// The returned [Future] completes after listeners have been notified.
  Future<void> _updateMapOptions(Map<String, dynamic> optionsUpdate) async {
    _cameraPosition = await _maplibreGlPlatform.updateMapOptions(optionsUpdate);
    notifyListeners();
  }

  /// Triggers a resize event for the map on web (ignored on Android or iOS).
  ///
  /// Checks first if a resize is required or if it looks like it is already correctly resized.
  /// If it looks good, the resize call will be skipped.
  ///
  /// To force resize map (without any checks) have a look at forceResizeWebMap()
  void resizeWebMap() {
    _maplibreGlPlatform.resizeWebMap();
  }

  /// Triggers a hard map resize event on web and does not check if it is required or not.
  void forceResizeWebMap() {
    _maplibreGlPlatform.forceResizeWebMap();
  }

  /// Starts an animated change of the map camera position.
  ///
  /// [duration] is the amount of time, that the transition animation should take.
  ///
  /// The returned [Future] completes after the change has been started on the
  /// platform side.
  /// It returns true if the camera was successfully moved and false if the movement was canceled.
  /// Note: this currently always returns immediately with a value of null on iOS
  Future<bool?> animateCamera(CameraUpdate cameraUpdate,
      {Duration? duration}) async {
    return _maplibreGlPlatform.animateCamera(cameraUpdate, duration: duration);
  }

  /// Instantaneously re-position the camera.
  /// Note: moveCamera() quickly moves the camera, which can be visually jarring for a user. Strongly consider using the animateCamera() methods instead because it's less abrupt.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  /// It returns true if the camera was successfully moved and false if the movement was canceled.
  /// Note: this currently always returns immediately with a value of null on iOS
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    return _maplibreGlPlatform.moveCamera(cameraUpdate);
  }

  /// Adds a new geojson source
  ///
  /// The json in [geojson] has to comply with the schema for FeatureCollection
  /// as specified in https://datatracker.ietf.org/doc/html/rfc7946#section-3.3
  ///
  /// [promoteId] can be used on web to promote an id from properties to be the
  /// id of the feature. This is useful because by default maplibre-gl-js does not
  /// support string ids
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson,
      {String? promoteId}) async {
    await _maplibreGlPlatform.addGeoJsonSource(sourceId, geojson,
        promoteId: promoteId);
  }

  /// Sets new geojson data to and existing source
  ///
  /// This only works as exected if the source has been created with
  /// [addGeoJsonSource] before. This is very useful if you want to update and
  /// existing source with modified data.
  ///
  /// The json in [geojson] has to comply with the schema for FeatureCollection
  /// as specified in https://datatracker.ietf.org/doc/html/rfc7946#section-3.3
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> setGeoJsonSource(
      String sourceId, Map<String, dynamic> geojson) async {
    await _maplibreGlPlatform.setGeoJsonSource(sourceId, geojson);
  }

  /// Sets new geojson data to and existing source
  ///
  /// This only works as exected if the source has been created with
  /// [addGeoJsonSource] before. This is very useful if you want to update and
  /// existing source with modified data.
  ///
  /// The json in [geojson] has to comply with the schema for FeatureCollection
  /// as specified in https://datatracker.ietf.org/doc/html/rfc7946#section-3.3
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> setGeoJsonFeature(
      String sourceId, Map<String, dynamic> geojsonFeature) async {
    await _maplibreGlPlatform.setFeatureForGeoJsonSource(
        sourceId, geojsonFeature);
  }

  /// Add a symbol layer to the map with the given properties
  ///
  /// Consider using [addLayer] for an unified layer api.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  ///
  /// Setting [belowLayerId] adds the new layer below the given id.
  /// If [enableInteraction] is set the layer is considered for touch or drag
  /// events. [sourceLayer] is used to selected a specific source layer from
  /// Vector source.
  /// [minzoom] is the minimum (inclusive) zoom level at which the layer is
  /// visible.
  /// [maxzoom] is the maximum (exclusive) zoom level at which the layer is
  /// visible.
  /// [filter] determines which features should be rendered in the layer.
  /// Filters are written as [expressions].
  ///
  /// [expressions]: https://maplibre.org/maplibre-style-spec/expressions/
  Future<void> addSymbolLayer(
      String sourceId, String layerId, SymbolLayerProperties properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      bool enableInteraction = true}) async {
    await _maplibreGlPlatform.addSymbolLayer(
      sourceId,
      layerId,
      properties.toJson(),
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  /// Add a line layer to the map with the given properties
  ///
  /// Consider using [addLayer] for an unified layer api.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  ///
  /// Setting [belowLayerId] adds the new layer below the given id.
  /// If [enableInteraction] is set the layer is considered for touch or drag
  /// events. [sourceLayer] is used to selected a specific source layer from
  /// Vector source.
  /// [minzoom] is the minimum (inclusive) zoom level at which the layer is
  /// visible.
  /// [maxzoom] is the maximum (exclusive) zoom level at which the layer is
  /// visible.
  /// [filter] determines which features should be rendered in the layer.
  /// Filters are written as [expressions].
  ///
  /// [expressions]: https://maplibre.org/maplibre-style-spec/expressions/
  Future<void> addLineLayer(
      String sourceId, String layerId, LineLayerProperties properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      bool enableInteraction = true}) async {
    await _maplibreGlPlatform.addLineLayer(
      sourceId,
      layerId,
      properties.toJson(),
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  /// Set one or multiple properties of a layer.
  /// You can only use properties that are supported for the layer's type.
  /// So you can e.g. only use LineLayerProperties on a line layer.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> setLayerProperties(
      String layerId, LayerProperties properties) async {
    await _maplibreGlPlatform.setLayerProperties(layerId, properties.toJson());
  }

  /// Add a fill layer to the map with the given properties
  ///
  /// Consider using [addLayer] for an unified layer api.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  ///
  /// Setting [belowLayerId] adds the new layer below the given id.
  /// If [enableInteraction] is set the layer is considered for touch or drag
  /// events. [sourceLayer] is used to selected a specific source layer from
  /// Vector source.
  /// [minzoom] is the minimum (inclusive) zoom level at which the layer is
  /// visible.
  /// [maxzoom] is the maximum (exclusive) zoom level at which the layer is
  /// visible.
  /// [filter] determines which features should be rendered in the layer.
  /// Filters are written as [expressions].
  ///
  /// [expressions]: https://maplibre.org/maplibre-style-spec/expressions/
  Future<void> addFillLayer(
      String sourceId, String layerId, FillLayerProperties properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      bool enableInteraction = true}) async {
    await _maplibreGlPlatform.addFillLayer(
      sourceId,
      layerId,
      properties.toJson(),
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  /// Add a circle layer to the map with the given properties
  ///
  /// Consider using [addLayer] for an unified layer api.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  ///
  /// Setting [belowLayerId] adds the new layer below the given id.
  /// If [enableInteraction] is set the layer is considered for touch or drag
  /// events. [sourceLayer] is used to selected a specific source layer from
  /// Vector source.
  /// [minzoom] is the minimum (inclusive) zoom level at which the layer is
  /// visible.
  /// [maxzoom] is the maximum (exclusive) zoom level at which the layer is
  /// visible.
  /// [filter] determines which features should be rendered in the layer.
  /// Filters are written as [expressions].
  ///
  /// [expressions]: https://maplibre.org/maplibre-style-spec/expressions/
  Future<void> addCircleLayer(
      String sourceId, String layerId, CircleLayerProperties properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      bool enableInteraction = true}) async {
    await _maplibreGlPlatform.addCircleLayer(
      sourceId,
      layerId,
      properties.toJson(),
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  /// Add a raster layer to the map with the given properties
  ///
  /// Consider using [addLayer] for an unified layer api.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  ///
  /// Setting [belowLayerId] adds the new layer below the given id.
  /// [sourceLayer] is used to selected a specific source layer from
  /// Raster source.
  /// [minzoom] is the minimum (inclusive) zoom level at which the layer is
  /// visible.
  /// [maxzoom] is the maximum (exclusive) zoom level at which the layer is
  /// visible.
  Future<void> addRasterLayer(
      String sourceId, String layerId, RasterLayerProperties properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) async {
    await _maplibreGlPlatform.addRasterLayer(
      sourceId,
      layerId,
      properties.toJson(),
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
    );
  }

  /// Add a hillshade layer to the map with the given properties
  ///
  /// Consider using [addLayer] for an unified layer api.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  ///
  /// Setting [belowLayerId] adds the new layer below the given id.
  /// [sourceLayer] is used to selected a specific source layer from
  /// Raster source.
  /// [minzoom] is the minimum (inclusive) zoom level at which the layer is
  /// visible.
  /// [maxzoom] is the maximum (exclusive) zoom level at which the layer is
  /// visible.
  Future<void> addHillshadeLayer(
      String sourceId, String layerId, HillshadeLayerProperties properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) async {
    await _maplibreGlPlatform.addHillshadeLayer(
      sourceId,
      layerId,
      properties.toJson(),
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
    );
  }

  /// Updates user location tracking mode.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> updateMyLocationTrackingMode(
      MyLocationTrackingMode myLocationTrackingMode) async {
    return _maplibreGlPlatform
        .updateMyLocationTrackingMode(myLocationTrackingMode);
  }

  /// Updates the language of the map labels to match the device's language.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> matchMapLanguageWithDeviceDefault() async {
    return _maplibreGlPlatform.matchMapLanguageWithDeviceDefault();
  }

  /// Updates the distance from the edges of the map view’s frame to the edges
  /// of the map view’s logical viewport, optionally animating the change.
  ///
  /// When the value of this property is equal to `EdgeInsets.zero`, viewport
  /// properties such as centerCoordinate assume a viewport that matches the map
  /// view’s frame. Otherwise, those properties are inset, excluding part of the
  /// frame from the viewport. For instance, if the only the top edge is inset,
  /// the map center is effectively shifted downward.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> updateContentInsets(EdgeInsets insets,
      [bool animated = false]) async {
    return _maplibreGlPlatform.updateContentInsets(insets, animated);
  }

  /// Updates the language of the map labels to match the specified language.
  /// This will use labels with "name:$language" if available, otherwise "name:latin" or "name".
  /// This naming schema is used by OpenStreetMap (see [https://wiki.openstreetmap.org/wiki/Multilingual_names]),
  /// and is also used by some other vector tile generation software and vector tile providers.
  /// Commonly, (and according to the OSM wiki) [language] should be
  /// "a lowercase language's ISO 639-1 alpha2 code (second column), a lowercase ISO 639-2 code if an ISO 639-1 code doesn't exist, or a ISO 639-3 code if neither of those exist".
  ///
  /// If your vector tiles do not follow this schema of having labels with "name:$language" for different language, this method will not work for you.
  /// In that case, you need to adapt your Maplibre style accordingly yourself to use labels in your preferred language.
  ///
  /// Attention: This may only be called after onStyleLoaded() has been invoked.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> setMapLanguage(String language) async {
    return _maplibreGlPlatform.setMapLanguage(language);
  }

  /// Enables or disables the collection of anonymized telemetry data.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> setTelemetryEnabled(bool enabled) async {
    return _maplibreGlPlatform.setTelemetryEnabled(enabled);
  }

  /// Retrieves whether collection of anonymized telemetry data is enabled.
  ///
  /// The returned [Future] completes after the query has been made on the
  /// platform side.
  Future<bool> getTelemetryEnabled() async {
    return _maplibreGlPlatform.getTelemetryEnabled();
  }

  /// Adds a symbol to the map, configured using the specified custom [options].
  ///
  /// Change listeners are notified once the symbol has been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added symbol once listeners have
  /// been notified.
  Future<Symbol> addSymbol(SymbolOptions options, [Map? data]) async {
    final effectiveOptions = SymbolOptions.defaultOptions.copyWith(options);
    final symbol = Symbol(getRandomString(), effectiveOptions, data);
    await symbolManager!.add(symbol);
    notifyListeners();
    return symbol;
  }

  /// Adds multiple symbols to the map, configured using the specified custom
  /// [options].
  ///
  /// Change listeners are notified once the symbol has been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added symbol once listeners have
  /// been notified.
  Future<List<Symbol>> addSymbols(List<SymbolOptions> options,
      [List<Map>? data]) async {
    final symbols = [
      for (var i = 0; i < options.length; i++)
        Symbol(getRandomString(),
            SymbolOptions.defaultOptions.copyWith(options[i]), data?[i])
    ];
    await symbolManager!.addAll(symbols);

    notifyListeners();
    return symbols;
  }

  /// Updates the specified [symbol] with the given [changes]. The symbol must
  /// be a current member of the [symbols] set.
  ///
  /// Change listeners are notified once the symbol has been updated on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes) async {
    await symbolManager!
        .set(symbol..options = symbol.options.copyWith(changes));

    notifyListeners();
  }

  /// Retrieves the current position of the symbol.
  /// This may be different from the value of `symbol.options.geometry` if the symbol is draggable.
  /// In that case this method provides the symbol's actual position, and `symbol.options.geometry` the last programmatically set position.
  Future<LatLng> getSymbolLatLng(Symbol symbol) async {
    return symbol.options.geometry!;
  }

  /// Removes the specified [symbol] from the map. The symbol must be a current
  /// member of the [symbols] set.
  ///
  /// Change listeners are notified once the symbol has been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeSymbol(Symbol symbol) async {
    await symbolManager!.remove(symbol);
    notifyListeners();
  }

  /// Removes the specified [symbols] from the map. The symbols must be current
  /// members of the [symbols] set.
  ///
  /// Change listeners are notified once the symbol has been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeSymbols(Iterable<Symbol> symbols) async {
    await symbolManager!.removeAll(symbols);
    notifyListeners();
  }

  /// Removes all [symbols] from the map added with the [addSymbol] or [addSymbols] methods.
  ///
  /// Change listeners are notified once all symbols have been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> clearSymbols() async {
    symbolManager!.clear();
    notifyListeners();
  }

  /// Adds a line to the map, configured using the specified custom [options].
  ///
  /// Change listeners are notified once the line has been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added line once listeners have
  /// been notified.
  Future<Line> addLine(LineOptions options, [Map? data]) async {
    final effectiveOptions = LineOptions.defaultOptions.copyWith(options);
    final line = Line(getRandomString(), effectiveOptions, data);
    await lineManager!.add(line);
    notifyListeners();
    return line;
  }

  /// Adds multiple lines to the map, configured using the specified custom [options].
  ///
  /// Change listeners are notified once the lines have been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added line once listeners have
  /// been notified.
  Future<List<Line>> addLines(List<LineOptions> options,
      [List<Map>? data]) async {
    final lines = [
      for (var i = 0; i < options.length; i++)
        Line(getRandomString(), LineOptions.defaultOptions.copyWith(options[i]),
            data?[i])
    ];
    await lineManager!.addAll(lines);

    notifyListeners();
    return lines;
  }

  /// Updates the specified [line] with the given [changes]. The line must
  /// be a current member of the [lines] set.‚
  ///
  /// Change listeners are notified once the line has been updated on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> updateLine(Line line, LineOptions changes) async {
    line.options = line.options.copyWith(changes);
    await lineManager!.set(line);
    notifyListeners();
  }

  /// Retrieves the current position of the line.
  /// This may be different from the value of `line.options.geometry` if the line is draggable.
  /// In that case this method provides the line's actual position, and `line.options.geometry` the last programmatically set position.
  Future<List<LatLng>> getLineLatLngs(Line line) async {
    return line.options.geometry!;
  }

  /// Removes the specified [line] from the map. The line must be a current
  /// member of the [lines] set.
  ///
  /// Change listeners are notified once the line has been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeLine(Line line) async {
    await lineManager!.remove(line);
    notifyListeners();
  }

  /// Removes the specified [lines] from the map. The lines must be current
  /// members of the [lines] set.
  ///
  /// Change listeners are notified once the lines have been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeLines(Iterable<Line> lines) async {
    await lineManager!.removeAll(lines);
    notifyListeners();
  }

  /// Removes all [lines] from the map added with the [addLine] or [addLines] methods.
  ///
  /// Change listeners are notified once all lines have been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> clearLines() async {
    await lineManager!.clear();
    notifyListeners();
  }

  /// Adds a circle to the map, configured using the specified custom [options].
  ///
  /// Change listeners are notified once the circle has been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added circle once listeners have
  /// been notified.
  Future<Circle> addCircle(CircleOptions options, [Map? data]) async {
    final CircleOptions effectiveOptions =
        CircleOptions.defaultOptions.copyWith(options);
    final circle = Circle(getRandomString(), effectiveOptions, data);
    await circleManager!.add(circle);
    notifyListeners();
    return circle;
  }

  /// Adds multiple circles to the map, configured using the specified custom
  /// [options].
  ///
  /// Change listeners are notified once the circles have been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added circle once listeners have
  /// been notified.
  Future<List<Circle>> addCircles(List<CircleOptions> options,
      [List<Map>? data]) async {
    final cricles = [
      for (var i = 0; i < options.length; i++)
        Circle(getRandomString(),
            CircleOptions.defaultOptions.copyWith(options[i]), data?[i])
    ];
    await circleManager!.addAll(cricles);

    notifyListeners();
    return cricles;
  }

  /// Updates the specified [circle] with the given [changes]. The circle must
  /// be a current member of the [circles] set.
  ///
  /// Change listeners are notified once the circle has been updated on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> updateCircle(Circle circle, CircleOptions changes) async {
    circle.options = circle.options.copyWith(changes);
    await circleManager!.set(circle);

    notifyListeners();
  }

  /// Retrieves the current position of the circle.
  /// This may be different from the value of `circle.options.geometry` if the circle is draggable.
  /// In that case this method provides the circle's actual position, and `circle.options.geometry` the last programmatically set position.
  Future<LatLng> getCircleLatLng(Circle circle) async {
    return circle.options.geometry!;
  }

  /// Removes the specified [circle] from the map. The circle must be a current
  /// member of the [circles] set.
  ///
  /// Change listeners are notified once the circle has been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeCircle(Circle circle) async {
    circleManager!.remove(circle);

    notifyListeners();
  }

  /// Removes the specified [circles] from the map. The circles must be current
  /// members of the [circles] set.
  ///
  /// Change listeners are notified once the circles have been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeCircles(Iterable<Circle> circles) async {
    await circleManager!.removeAll(circles);
    notifyListeners();
  }

  /// Removes all [circles] from the map added with the [addCircle] or [addCircles] methods.
  ///
  /// Change listeners are notified once all circles have been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> clearCircles() async {
    circleManager!.clear();

    notifyListeners();
  }

  /// Adds a fill to the map, configured using the specified custom [options].
  ///
  /// Change listeners are notified once the fill has been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added fill once listeners have
  /// been notified.
  Future<Fill> addFill(FillOptions options, [Map? data]) async {
    final FillOptions effectiveOptions =
        FillOptions.defaultOptions.copyWith(options);
    final fill = Fill(getRandomString(), effectiveOptions, data);
    await fillManager!.add(fill);
    notifyListeners();
    return fill;
  }

  /// Adds multiple fills to the map, configured using the specified custom
  /// [options].
  ///
  /// Change listeners are notified once the fills has been added on the
  /// platform side.
  ///
  /// The returned [Future] completes with the added fills once listeners have
  /// been notified.
  Future<List<Fill>> addFills(List<FillOptions> options,
      [List<Map>? data]) async {
    final fills = [
      for (var i = 0; i < options.length; i++)
        Fill(getRandomString(), FillOptions.defaultOptions.copyWith(options[i]),
            data?[i])
    ];
    await fillManager!.addAll(fills);

    notifyListeners();
    return fills;
  }

  /// Updates the specified [fill] with the given [changes]. The fill must
  /// be a current member of the [fills] set.
  ///
  /// Change listeners are notified once the fill has been updated on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> updateFill(Fill fill, FillOptions changes) async {
    fill.options = fill.options.copyWith(changes);
    await fillManager!.set(fill);

    notifyListeners();
  }

  /// Removes all [fills] from the map added with the [addFill] or [addFills] methods.
  ///
  /// Change listeners are notified once all fills have been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> clearFills() async {
    await fillManager!.clear();

    notifyListeners();
  }

  /// Removes the specified [fill] from the map. The fill must be a current
  /// member of the [fills] set.
  ///
  /// Change listeners are notified once the fill has been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeFill(Fill fill) async {
    await fillManager!.remove(fill);
    notifyListeners();
  }

  /// Removes the specified [fills] from the map. The fills must be current
  /// members of the [fills] set.
  ///
  /// Change listeners are notified once the fills have been removed on the
  /// platform side.
  ///
  /// The returned [Future] completes once listeners have been notified.
  Future<void> removeFills(Iterable<Fill> fills) async {
    await fillManager!.removeAll(fills);
    notifyListeners();
  }

  /// Query rendered features at a point in screen cooridnates
  Future<List> queryRenderedFeatures(
      Point<double> point, List<String> layerIds, List<Object>? filter) async {
    return _maplibreGlPlatform.queryRenderedFeatures(point, layerIds, filter);
  }

  /// Query rendered features in a Rect in screen coordinates
  Future<List> queryRenderedFeaturesInRect(
      Rect rect, List<String> layerIds, String? filter) async {
    return _maplibreGlPlatform.queryRenderedFeaturesInRect(
        rect, layerIds, filter);
  }

  /// Query rendered features at a point in screen coordinates
  /// Note: On web, this will probably only work for GeoJson source, not for vector tiles
  Future<List> querySourceFeatures(
      String sourceId, String? sourceLayerId, List<Object>? filter) async {
    return _maplibreGlPlatform.querySourceFeatures(
        sourceId, sourceLayerId, filter);
  }

  Future invalidateAmbientCache() async {
    return _maplibreGlPlatform.invalidateAmbientCache();
  }

  /// Get last my location
  ///
  /// Return last latlng, nullable
  Future<LatLng?> requestMyLocationLatLng() async {
    return _maplibreGlPlatform.requestMyLocationLatLng();
  }

  /// This method returns the boundaries of the region currently displayed in the map.
  Future<LatLngBounds> getVisibleRegion() async {
    return _maplibreGlPlatform.getVisibleRegion();
  }

  /// Adds an image to the style currently displayed in the map, so that it can later be referred to by the provided name.
  ///
  /// This allows you to add an image to the currently displayed style once, and from there on refer to it e.g. in the [Symbol.iconImage] anytime you add a [Symbol] later on.
  /// Set [sdf] to true if the image you add is an SDF image.
  /// Returns after the image has successfully been added to the style.
  /// Note: This can only be called after OnStyleLoadedCallback has been invoked and any added images will have to be re-added if a new style is loaded.
  ///
  /// Example: Adding an asset image and using it in a new symbol:
  /// ```dart
  /// Future<void> addImageFromAsset() async{
  ///   final ByteData bytes = await rootBundle.load("assets/someAssetImage.jpg");
  ///   final Uint8List list = bytes.buffer.asUint8List();
  ///   await controller.addImage("assetImage", list);
  ///   controller.addSymbol(
  ///    SymbolOptions(
  ///     geometry: LatLng(0,0),
  ///     iconImage: "assetImage",
  ///    ),
  ///   );
  /// }
  /// ```
  ///
  /// Example: Adding a network image (with the http package) and using it in a new symbol:
  /// ```dart
  /// Future<void> addImageFromUrl() async{
  ///  var response = await get("https://example.com/image.png");
  ///  await controller.addImage("testImage",  response.bodyBytes);
  ///  controller.addSymbol(
  ///   SymbolOptions(
  ///     geometry: LatLng(0,0),
  ///     iconImage: "testImage",
  ///   ),
  ///  );
  /// }
  /// ```
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) {
    return _maplibreGlPlatform.addImage(name, bytes, sdf);
  }

  /// If true, the icon will be visible even if it collides with other previously drawn symbols.
  Future<void> setSymbolIconAllowOverlap(bool enable) async {
    await symbolManager?.setIconAllowOverlap(enable);
  }

  /// If true, other symbols can be visible even if they collide with the icon.
  Future<void> setSymbolIconIgnorePlacement(bool enable) async {
    await symbolManager?.setIconIgnorePlacement(enable);
  }

  /// If true, the text will be visible even if it collides with other previously drawn symbols.
  Future<void> setSymbolTextAllowOverlap(bool enable) async {
    await symbolManager?.setTextAllowOverlap(enable);
  }

  /// If true, other symbols can be visible even if they collide with the text.
  Future<void> setSymbolTextIgnorePlacement(bool enable) async {
    await symbolManager?.setTextIgnorePlacement(enable);
  }

  /// Adds an image source to the style currently displayed in the map, so that it can later be referred to by the provided id.
  /// Not implemented on web.
  Future<void> addImageSource(
      String imageSourceId, Uint8List bytes, LatLngQuad coordinates) {
    return _maplibreGlPlatform.addImageSource(
        imageSourceId, bytes, coordinates);
  }

  /// Update the image and/or coordinates of an image source.
  /// Not implemented on web.
  Future<void> updateImageSource(
      String imageSourceId, Uint8List? bytes, LatLngQuad? coordinates) {
    return _maplibreGlPlatform.updateImageSource(
        imageSourceId, bytes, coordinates);
  }

  /// Removes previously added image source by id
  @Deprecated("This method was renamed to removeSource")
  Future<void> removeImageSource(String imageSourceId) {
    return _maplibreGlPlatform.removeSource(imageSourceId);
  }

  /// Removes previously added source by id
  Future<void> removeSource(String sourceId) {
    return _maplibreGlPlatform.removeSource(sourceId);
  }

  /// Adds an image layer to the map's style at render time.
  Future<void> addImageLayer(String layerId, String imageSourceId,
      {double? minzoom, double? maxzoom}) {
    return _maplibreGlPlatform.addLayer(
        layerId, imageSourceId, minzoom, maxzoom);
  }

  /// Adds an image layer below the layer provided with belowLayerId to the map's style at render time.
  Future<void> addImageLayerBelow(
      String layerId, String sourceId, String imageSourceId,
      {double? minzoom, double? maxzoom}) {
    return _maplibreGlPlatform.addLayerBelow(
        layerId, sourceId, imageSourceId, minzoom, maxzoom);
  }

  /// Adds an image layer below the layer provided with belowLayerId to the map's style at render time. Only works for image sources!
  @Deprecated("This method was renamed to addImageLayerBelow for clarity.")
  Future<void> addLayerBelow(
      String layerId, String sourceId, String imageSourceId,
      {double? minzoom, double? maxzoom}) {
    return _maplibreGlPlatform.addLayerBelow(
        layerId, sourceId, imageSourceId, minzoom, maxzoom);
  }

  /// Removes a MapLibre style layer
  Future<void> removeLayer(String layerId) {
    return _maplibreGlPlatform.removeLayer(layerId);
  }

  Future<void> setFilter(String layerId, dynamic filter) {
    return _maplibreGlPlatform.setFilter(layerId, filter);
  }

  Future<dynamic> getFilter(String layerId) {
    return _maplibreGlPlatform.getFilter(layerId);
  }

  /// Returns the point on the screen that corresponds to a geographical coordinate ([latLng]). The screen location is in screen pixels (not display pixels) relative to the top left of the map (not of the whole screen)
  ///
  /// Note: The resulting x and y coordinates are rounded to [int] on web, on other platforms they may differ very slightly (in the range of about 10^-10) from the actual nearest screen coordinate.
  /// You therefore might want to round them appropriately, depending on your use case.
  ///
  /// Returns null if [latLng] is not currently visible on the map.
  Future<Point> toScreenLocation(LatLng latLng) async {
    return _maplibreGlPlatform.toScreenLocation(latLng);
  }

  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) async {
    return _maplibreGlPlatform.toScreenLocationBatch(latLngs);
  }

  /// Returns the geographic location (as [LatLng]) that corresponds to a point on the screen. The screen location is specified in screen pixels (not display pixels) relative to the top left of the map (not the top left of the whole screen).
  Future<LatLng> toLatLng(Point screenLocation) async {
    return _maplibreGlPlatform.toLatLng(screenLocation);
  }

  /// Returns the distance spanned by one pixel at the specified [latitude] and current zoom level.
  /// The distance between pixels decreases as the latitude approaches the poles. This relationship parallels the relationship between longitudinal coordinates at different latitudes.
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    return _maplibreGlPlatform.getMetersPerPixelAtLatitude(latitude);
  }

  /// Add a new source to the map
  Future<void> addSource(String sourceid, SourceProperties properties) async {
    return _maplibreGlPlatform.addSource(sourceid, properties);
  }

  Future setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {
    return _maplibreGlPlatform.setCameraBounds(
      west: west,
      north: north,
      south: south,
      east: east,
      padding: padding,
    );
  }

  /// Add a layer to the map with the given properties
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  ///
  /// Setting [belowLayerId] adds the new layer below the given id.
  /// If [enableInteraction] is set the layer is considered for touch or drag
  /// events this has no effect for [RasterLayerProperties] and
  /// [HillshadeLayerProperties].
  /// [sourceLayer] is used to selected a specific source layer from Vector
  /// source.
  /// [minzoom] is the minimum (inclusive) zoom level at which the layer is
  /// visible.
  /// [maxzoom] is the maximum (exclusive) zoom level at which the layer is
  /// visible.
  /// [filter] determines which features should be rendered in the layer.
  /// Filters are written as [expressions].
  /// [filter] is not supported by RasterLayer and HillshadeLayer.
  ///
  /// [expressions]: https://maplibre.org/maplibre-style-spec/expressions/
  Future<void> addLayer(
      String sourceId, String layerId, LayerProperties properties,
      {String? belowLayerId,
      bool enableInteraction = true,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter}) async {
    if (properties is FillLayerProperties) {
      addFillLayer(sourceId, layerId, properties,
          belowLayerId: belowLayerId,
          enableInteraction: enableInteraction,
          sourceLayer: sourceLayer,
          minzoom: minzoom,
          maxzoom: maxzoom,
          filter: filter);
    } else if (properties is LineLayerProperties) {
      addLineLayer(sourceId, layerId, properties,
          belowLayerId: belowLayerId,
          enableInteraction: enableInteraction,
          sourceLayer: sourceLayer,
          minzoom: minzoom,
          maxzoom: maxzoom,
          filter: filter);
    } else if (properties is SymbolLayerProperties) {
      addSymbolLayer(sourceId, layerId, properties,
          belowLayerId: belowLayerId,
          enableInteraction: enableInteraction,
          sourceLayer: sourceLayer,
          minzoom: minzoom,
          maxzoom: maxzoom,
          filter: filter);
    } else if (properties is CircleLayerProperties) {
      addCircleLayer(sourceId, layerId, properties,
          belowLayerId: belowLayerId,
          enableInteraction: enableInteraction,
          sourceLayer: sourceLayer,
          minzoom: minzoom,
          maxzoom: maxzoom,
          filter: filter);
    } else if (properties is RasterLayerProperties) {
      if (filter != null) {
        throw UnimplementedError("RasterLayer does not support filter");
      }
      addRasterLayer(sourceId, layerId, properties,
          belowLayerId: belowLayerId,
          sourceLayer: sourceLayer,
          minzoom: minzoom,
          maxzoom: maxzoom);
    } else if (properties is HillshadeLayerProperties) {
      if (filter != null) {
        throw UnimplementedError("HillShadeLayer does not support filter");
      }
      addHillshadeLayer(sourceId, layerId, properties,
          belowLayerId: belowLayerId,
          sourceLayer: sourceLayer,
          minzoom: minzoom,
          maxzoom: maxzoom);
    } else {
      throw UnimplementedError("Unknown layer type $properties");
    }
  }

  Future<void> setLayerVisibility(String layerId, bool visible) async {
    return _maplibreGlPlatform.setLayerVisibility(layerId, visible);
  }

  Future<List> getLayerIds() {
    return _maplibreGlPlatform.getLayerIds();
  }

  /// Retrieve every source ids of the map as a [String] list, including the ones added internally
  ///
  /// This method is not currently implemented on the web
  Future<List<String>> getSourceIds() async {
    return (await _maplibreGlPlatform.getSourceIds())
        .whereType<String>()
        .toList();
  }

  @override
  void dispose() {
    super.dispose();
    _maplibreGlPlatform.dispose();
  }
}
