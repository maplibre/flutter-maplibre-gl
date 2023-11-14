// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of maplibre_gl;

enum AnnotationType { fill, line, circle, symbol }

typedef void MapCreatedCallback(MaplibreMapController controller);

/// Shows a MapLibre map.
/// Also refer to the documentation of [maplibre_gl] and [MaplibreMapController].
class MaplibreMap extends StatefulWidget {
  const MaplibreMap({
    Key? key,
    required this.initialCameraPosition,
    this.onMapCreated,
    this.onStyleLoadedCallback,
    this.gestureRecognizers,
    this.compassEnabled = true,
    this.cameraTargetBounds = CameraTargetBounds.unbounded,
    this.styleString,
    this.minMaxZoomPreference = MinMaxZoomPreference.unbounded,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.doubleClickZoomEnabled,
    this.dragEnabled = true,
    this.trackCameraPosition = false,
    this.myLocationEnabled = false,
    this.myLocationTrackingMode = MyLocationTrackingMode.None,
    this.myLocationRenderMode = MyLocationRenderMode.NORMAL,
    this.logoViewMargins,
    this.compassViewPosition,
    this.compassViewMargins,
    this.attributionButtonPosition = AttributionButtonPosition.BottomRight,
    this.attributionButtonMargins,
    this.onMapClick,
    this.onUserLocationUpdated,
    this.onMapLongClick,
    this.onCameraTrackingDismissed,
    this.onCameraTrackingChanged,
    this.onCameraIdle,
    this.onMapIdle,
    this.annotationOrder = const [
      AnnotationType.line,
      AnnotationType.symbol,
      AnnotationType.circle,
      AnnotationType.fill,
    ],
    this.annotationConsumeTapEvents = const [
      AnnotationType.symbol,
      AnnotationType.fill,
      AnnotationType.line,
      AnnotationType.circle,
    ],
  })  : assert(
          myLocationRenderMode != MyLocationRenderMode.NORMAL
              ? myLocationEnabled
              : true,
          "$myLocationRenderMode requires [myLocationEnabled] set to true.",
        ),
        assert(annotationOrder.length <= 4),
        assert(annotationConsumeTapEvents.length > 0),
        super(key: key);

  /// Defines the layer order of annotations displayed on map
  ///
  /// Any annotation type can only be contained once, so 0 to 4 types
  ///
  /// Note that setting this to be empty gives a big perfomance boost for
  /// android. However if you do so annotations will not work.
  final List<AnnotationType> annotationOrder;

  /// Defines the layer order of click annotations
  ///
  /// (must contain at least 1 annotation type, 4 items max)
  final List<AnnotationType> annotationConsumeTapEvents;

  /// Please note: you should only add annotations (e.g. symbols or circles) after `onStyleLoadedCallback` has been called.
  final MapCreatedCallback? onMapCreated;

  /// Called when the map style has been successfully loaded and the annotation managers have been enabled.
  /// Please note: you should only add annotations (e.g. symbols or circles) after this callback has been called.
  final OnStyleLoadedCallback? onStyleLoadedCallback;

  /// The initial position of the map's camera.
  final CameraPosition initialCameraPosition;

  /// True if the map should show a compass when rotated.
  final bool compassEnabled;

  /// True if drag functionality should be enabled.
  ///
  /// Disable to avoid performance issues that from the drag event listeners.
  /// Biggest impact in android
  final bool dragEnabled;

  /// Geographical bounding box for the camera target.
  final CameraTargetBounds cameraTargetBounds;

  /// A MapLibre GL style document defining the map's appearance.
  /// The style document specification is at [https://maplibre.org/maplibre-style-spec].
  /// A short introduction can be found in the documentation of the [maplibre_gl] library.
  /// The following formats are supported:
  ///
  /// 1. Passing the URL of the map style. This should be a custom map style served remotely using a URL that start with 'http(s)://'
  /// 2. Passing the style as a local asset. Create a JSON file in the `assets` and add a reference in `pubspec.yml`. Set the style string to the relative path for this asset in order to load it into the map.
  /// 3. Passing the style as a local file. create an JSON file in app directory (e.g. ApplicationDocumentsDirectory). Set the style string to the absolute path of this JSON file.
  /// 4. Passing the raw JSON of the map style. This is only supported on Android.
  final String? styleString;

  /// Preferred bounds for the camera zoom level.
  ///
  /// Actual bounds depend on map data and device.
  final MinMaxZoomPreference minMaxZoomPreference;

  /// True if the map view should respond to rotate gestures.
  final bool rotateGesturesEnabled;

  /// True if the map view should respond to scroll gestures.
  final bool scrollGesturesEnabled;

  /// True if the map view should respond to zoom gestures.
  final bool zoomGesturesEnabled;

  /// True if the map view should respond to tilt gestures.
  final bool tiltGesturesEnabled;

  /// Set to true to forcefully disable/enable if map should respond to double
  /// click to zoom.
  ///
  /// This takes presedence over zoomGesturesEnabled. Only supported for web.
  final bool? doubleClickZoomEnabled;

  /// True if you want to be notified of map camera movements by the [MaplibreMapController]. Default is false.
  ///
  /// If this is set to true and the user pans/zooms/rotates the map, [MaplibreMapController] (which is a [ChangeNotifier])
  /// will notify it's listeners and you can then get the new [MaplibreMapController].cameraPosition.
  final bool trackCameraPosition;

  /// True if a "My Location" layer should be shown on the map.
  ///
  /// This layer includes a location indicator at the current device location,
  /// as well as a My Location button.
  /// * The indicator is a small blue dot if the device is stationary, or a
  /// chevron if the device is moving.
  /// * The My Location button animates to focus on the user's current location
  /// if the user's location is currently known.
  ///
  /// Enabling this feature requires adding location permissions to both native
  /// platforms of your app.
  /// * On Android add either
  /// `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />`
  /// or `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />`
  /// to your `AndroidManifest.xml` file. `ACCESS_COARSE_LOCATION` returns a
  /// location with an accuracy approximately equivalent to a city block, while
  /// `ACCESS_FINE_LOCATION` returns as precise a location as possible, although
  /// it consumes more battery power. You will also need to request these
  /// permissions during run-time. If they are not granted, the My Location
  /// feature will fail silently.
  /// * On iOS add a `NSLocationWhenInUseUsageDescription` key to your
  /// `Info.plist` file. This will automatically prompt the user for permissions
  /// when the map tries to turn on the My Location layer.
  final bool myLocationEnabled;

  /// The mode used to let the map's camera follow the device's physical location.
  /// `myLocationEnabled` needs to be true for values other than `MyLocationTrackingMode.None` to work.
  final MyLocationTrackingMode myLocationTrackingMode;

  /// Specifies if and how the user's heading/bearing is rendered in the user location indicator.
  /// See the documentation of [MyLocationRenderMode] for details.
  /// If this is set to a value other than [MyLocationRenderMode.NORMAL], [myLocationEnabled] needs to be true.
  final MyLocationRenderMode myLocationRenderMode;

  /// Set the layout margins for the Logo
  final Point? logoViewMargins;

  /// Set the position for the Compass
  final CompassViewPosition? compassViewPosition;

  /// Set the layout margins for the Compass
  final Point? compassViewMargins;

  /// Set the position for the MapLibre Attribution Button
  /// When set to null, the default value of the underlying MapLibre libraries is used,
  /// which differs depending on the operating system the app is being run on.
  final AttributionButtonPosition? attributionButtonPosition;

  /// Set the layout margins for the MapLibre Attribution Buttons. If you set this
  /// value, you may also want to set [attributionButtonPosition] to harmonize
  /// the layout between iOS and Android, since the underlying frameworks have
  /// different defaults.
  final Point? attributionButtonMargins;

  /// Which gestures should be consumed by the map.
  ///
  /// It is possible for other gesture recognizers to be competing with the map on pointer
  /// events, e.g if the map is inside a [ListView] the [ListView] will want to handle
  /// vertical drags. The map will claim gestures that are recognized by any of the
  /// recognizers on this list.
  ///
  /// When this set is empty or null, the map will only handle pointer events for gestures that
  /// were not claimed by any other gesture recognizer.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  final OnMapClickCallback? onMapClick;
  final OnMapClickCallback? onMapLongClick;

  /// While the `myLocationEnabled` property is set to `true`, this method is
  /// called whenever a new location update is received by the map view.
  final OnUserLocationUpdated? onUserLocationUpdated;

  /// Called when the map's camera no longer follows the physical device location, e.g. because the user moved the map
  final OnCameraTrackingDismissedCallback? onCameraTrackingDismissed;

  /// Called when the location tracking mode changes
  final OnCameraTrackingChangedCallback? onCameraTrackingChanged;

  // Called when camera movement has ended.
  final OnCameraIdleCallback? onCameraIdle;

  /// Called when map view is entering an idle state, and no more drawing will
  /// be necessary until new data is loaded or there is some interaction with
  /// the map.
  /// * No camera transitions are in progress
  /// * All currently requested tiles have loaded
  /// * All fade/transition animations have completed
  final OnMapIdleCallback? onMapIdle;

  /// Set `MaplibreMap.useHybridComposition` to `false` in order use Virtual-Display
  /// (better for Android 9 and below but may result in errors on Android 12)
  /// or leave it `true` (default) to use Hybrid composition (Slower on Android 9 and below).
  static bool get useHybridComposition =>
      MethodChannelMaplibreGl.useHybridComposition;

  static set useHybridComposition(bool useHybridComposition) =>
      MethodChannelMaplibreGl.useHybridComposition = useHybridComposition;

  @override
  State createState() => _MaplibreMapState();
}

class _MaplibreMapState extends State<MaplibreMap> {
  final Completer<MaplibreMapController> _controller =
      Completer<MaplibreMapController>();

  late _MaplibreMapOptions _maplibreMapOptions;
  final MapLibreGlPlatform _maplibreGlPlatform =
      MapLibreGlPlatform.createInstance();

  @override
  Widget build(BuildContext context) {
    assert(
        widget.annotationOrder.toSet().length == widget.annotationOrder.length,
        "annotationOrder must not have duplicate types");
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'initialCameraPosition': widget.initialCameraPosition.toMap(),
      'options': _MaplibreMapOptions.fromWidget(widget).toMap(),
      //'onAttributionClickOverride': widget.onAttributionClick != null,
      'dragEnabled': widget.dragEnabled,
    };
    return _maplibreGlPlatform.buildView(
        creationParams, onPlatformViewCreated, widget.gestureRecognizers);
  }

  @override
  void initState() {
    super.initState();
    _maplibreMapOptions = _MaplibreMapOptions.fromWidget(widget);
  }

  @override
  void dispose() async {
    super.dispose();
    if (_controller.isCompleted) {
      final controller = await _controller.future;
      controller.dispose();
    }
  }

  @override
  void didUpdateWidget(MaplibreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final _MaplibreMapOptions newOptions =
        _MaplibreMapOptions.fromWidget(widget);
    final Map<String, dynamic> updates =
        _maplibreMapOptions.updatesMap(newOptions);
    _updateOptions(updates);
    _maplibreMapOptions = newOptions;
  }

  void _updateOptions(Map<String, dynamic> updates) async {
    if (updates.isEmpty) {
      return;
    }
    final MaplibreMapController controller = await _controller.future;
    controller._updateMapOptions(updates);
  }

  Future<void> onPlatformViewCreated(int id) async {
    final MaplibreMapController controller = MaplibreMapController(
      maplibreGlPlatform: _maplibreGlPlatform,
      initialCameraPosition: widget.initialCameraPosition,
      onStyleLoadedCallback: () {
        if (_controller.isCompleted) {
          widget.onStyleLoadedCallback?.call();
        } else {
          _controller.future.then((_) => widget.onStyleLoadedCallback?.call());
        }
      },
      onMapClick: widget.onMapClick,
      onUserLocationUpdated: widget.onUserLocationUpdated,
      onMapLongClick: widget.onMapLongClick,
      onCameraTrackingDismissed: widget.onCameraTrackingDismissed,
      onCameraTrackingChanged: widget.onCameraTrackingChanged,
      onCameraIdle: widget.onCameraIdle,
      onMapIdle: widget.onMapIdle,
      annotationOrder: widget.annotationOrder,
      annotationConsumeTapEvents: widget.annotationConsumeTapEvents,
    );
    await _maplibreGlPlatform.initPlatform(id);
    _controller.complete(controller);
    if (widget.onMapCreated != null) {
      widget.onMapCreated!(controller);
    }
  }
}

/// Configuration options for the MaplibreMap user interface.
///
/// When used to change configuration, null values will be interpreted as
/// "do not change this configuration option".
class _MaplibreMapOptions {
  _MaplibreMapOptions({
    this.compassEnabled,
    this.cameraTargetBounds,
    this.styleString,
    this.minMaxZoomPreference,
    required this.rotateGesturesEnabled,
    required this.scrollGesturesEnabled,
    required this.tiltGesturesEnabled,
    required this.zoomGesturesEnabled,
    required this.doubleClickZoomEnabled,
    this.trackCameraPosition,
    this.myLocationEnabled,
    this.myLocationTrackingMode,
    this.myLocationRenderMode,
    this.logoViewMargins,
    this.compassViewPosition,
    this.compassViewMargins,
    this.attributionButtonPosition,
    this.attributionButtonMargins,
  });

  static _MaplibreMapOptions fromWidget(MaplibreMap map) {
    return _MaplibreMapOptions(
      compassEnabled: map.compassEnabled,
      cameraTargetBounds: map.cameraTargetBounds,
      styleString: map.styleString,
      minMaxZoomPreference: map.minMaxZoomPreference,
      rotateGesturesEnabled: map.rotateGesturesEnabled,
      scrollGesturesEnabled: map.scrollGesturesEnabled,
      tiltGesturesEnabled: map.tiltGesturesEnabled,
      trackCameraPosition: map.trackCameraPosition,
      zoomGesturesEnabled: map.zoomGesturesEnabled,
      doubleClickZoomEnabled:
          map.doubleClickZoomEnabled ?? map.zoomGesturesEnabled,
      myLocationEnabled: map.myLocationEnabled,
      myLocationTrackingMode: map.myLocationTrackingMode,
      myLocationRenderMode: map.myLocationRenderMode,
      logoViewMargins: map.logoViewMargins,
      compassViewPosition: map.compassViewPosition,
      compassViewMargins: map.compassViewMargins,
      attributionButtonPosition: map.attributionButtonPosition,
      attributionButtonMargins: map.attributionButtonMargins,
    );
  }

  final bool? compassEnabled;

  final CameraTargetBounds? cameraTargetBounds;

  final String? styleString;

  final MinMaxZoomPreference? minMaxZoomPreference;

  final bool rotateGesturesEnabled;

  final bool scrollGesturesEnabled;

  final bool tiltGesturesEnabled;

  final bool zoomGesturesEnabled;

  final bool doubleClickZoomEnabled;

  final bool? trackCameraPosition;

  final bool? myLocationEnabled;

  final MyLocationTrackingMode? myLocationTrackingMode;

  final MyLocationRenderMode? myLocationRenderMode;

  final Point? logoViewMargins;

  final CompassViewPosition? compassViewPosition;

  final Point? compassViewMargins;

  final AttributionButtonPosition? attributionButtonPosition;

  final Point? attributionButtonMargins;

  final _gestureGroup = {
    'rotateGesturesEnabled',
    'scrollGesturesEnabled',
    'tiltGesturesEnabled',
    'zoomGesturesEnabled',
    'doubleClickZoomEnabled'
  };

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> optionsMap = <String, dynamic>{};

    void addIfNonNull(String fieldName, dynamic value) {
      if (value != null) {
        optionsMap[fieldName] = value;
      }
    }

    List<dynamic>? pointToArray(Point? fieldName) {
      if (fieldName != null) {
        return <dynamic>[fieldName.x, fieldName.y];
      }

      return null;
    }

    addIfNonNull('compassEnabled', compassEnabled);
    addIfNonNull('cameraTargetBounds', cameraTargetBounds?.toJson());
    addIfNonNull('styleString', styleString);
    addIfNonNull('minMaxZoomPreference', minMaxZoomPreference?.toJson());

    addIfNonNull('rotateGesturesEnabled', rotateGesturesEnabled);
    addIfNonNull('scrollGesturesEnabled', scrollGesturesEnabled);
    addIfNonNull('tiltGesturesEnabled', tiltGesturesEnabled);
    addIfNonNull('zoomGesturesEnabled', zoomGesturesEnabled);
    addIfNonNull('doubleClickZoomEnabled', doubleClickZoomEnabled);

    addIfNonNull('trackCameraPosition', trackCameraPosition);
    addIfNonNull('myLocationEnabled', myLocationEnabled);
    addIfNonNull('myLocationTrackingMode', myLocationTrackingMode?.index);
    addIfNonNull('myLocationRenderMode', myLocationRenderMode?.index);
    addIfNonNull('logoViewMargins', pointToArray(logoViewMargins));
    addIfNonNull('compassViewPosition', compassViewPosition?.index);
    addIfNonNull('compassViewMargins', pointToArray(compassViewMargins));
    addIfNonNull('attributionButtonPosition', attributionButtonPosition?.index);
    addIfNonNull(
        'attributionButtonMargins', pointToArray(attributionButtonMargins));
    return optionsMap;
  }

  Map<String, dynamic> updatesMap(_MaplibreMapOptions newOptions) {
    final Map<String, dynamic> prevOptionsMap = toMap();
    final newOptionsMap = newOptions.toMap();

    // if any gesture is updated also all other gestures have to the saved to
    // the update

    final gesturesRequireUpdate =
        _gestureGroup.any((key) => newOptionsMap[key] != prevOptionsMap[key]);

    return newOptionsMap
      ..removeWhere((String key, dynamic value) {
        if (_gestureGroup.contains(key)) return !gesturesRequireUpdate;
        final oldValue = prevOptionsMap[key];
        if (oldValue is List && value is List) {
          return listEquals(oldValue, value);
        }
        return oldValue == value;
      });
  }
}
