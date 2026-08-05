// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl.dart';

enum AnnotationType { fill, line, circle, symbol }

typedef MapCreatedCallback = void Function(MapLibreMapController controller);

/// Shows a MapLibre map.
/// Also refer to the documentation of [maplibre_gl] and [MapLibreMapController].
class MapLibreMap extends StatefulWidget {
  const MapLibreMap({
    super.key,
    this.initialCameraPosition,
    this.styleString = MapLibreStyles.demo,
    this.onMapCreated,
    this.onStyleLoadedCallback,
    this.locationEnginePlatforms = LocationEnginePlatforms.defaultPlatform,
    this.locationSource = const PlatformLocationSource(),
    this.gestureRecognizers,
    this.compassEnabled = true,
    this.cameraTargetBounds = CameraTargetBounds.unbounded,
    this.minMaxZoomPreference = MinMaxZoomPreference.unbounded,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.doubleClickZoomEnabled,
    this.dragEnabled = true,
    this.featureTapsTriggersMapClick = false,
    this.trackCameraPosition = false,
    this.myLocationEnabled = false,
    this.myLocationTrackingMode = MyLocationTrackingMode.none,
    this.myLocationRenderMode = MyLocationRenderMode.normal,
    this.logoEnabled = false,
    this.logoViewPosition,
    this.logoViewMargins,
    this.compassViewPosition,
    this.compassViewMargins,
    this.attributionButtonPosition = AttributionButtonPosition.bottomRight,
    this.attributionButtonMargins,
    this.attributionButtonColor,
    this.scaleControlEnabled = false,
    this.scaleControlPosition = ScaleControlPosition.bottomLeft,
    this.scaleControlUnit = ScaleControlUnit.metric,
    this.iosLongClickDuration,
    this.webPreserveDrawingBuffer = false,
    this.onMapClick,
    this.onUserLocationUpdated,
    this.onMapLongClick,
    this.onCameraTrackingDismissed,
    this.onCameraTrackingChanged,
    this.onCameraMove,
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
    this.foregroundLoadColor = Colors.transparent,
    this.translucentTextureSurface = false,
  }) : assert(
         myLocationRenderMode == MyLocationRenderMode.normal ||
             myLocationEnabled,
         "$myLocationRenderMode requires [myLocationEnabled] set to true.",
       ),
       assert(annotationOrder.length <= 4),
       assert(annotationConsumeTapEvents.length > 0);

  /// The properties for the platform-specific location engine.
  /// Only has an impact if [myLocationEnabled] is set to true.
  final LocationEnginePlatforms locationEnginePlatforms;

  /// Selects which source feeds the map's user-location component (the puck).
  ///
  /// Defaults to [PlatformLocationSource] (the native location engine). Use
  /// [ManualLocationSource] to feed app-provided locations via
  /// [MapLibreMapController.updateManualLocation] instead of the device's
  /// location engine.
  ///
  /// Only has an effect when [myLocationEnabled] is set to true. In manual mode
  /// no location permission is required. Applied at component activation;
  /// changing it after the map is created does not re-activate the component.
  ///
  /// Supported on Android, iOS and web. On Android and iOS the updates pushed
  /// via [MapLibreMapController.updateManualLocation] drive the SDK's native
  /// user-location component; on web the plugin draws the puck itself (dot +
  /// accuracy circle + bearing arrow) using map markers.
  final LocationSource locationSource;

  /// The color used for the map loading foreground.
  /// Pass a [Color] and it will be converted to ARGB int for the platform.
  ///
  /// **Available only on Android. Has no effect on iOS or Web.**
  final Color? foregroundLoadColor;

  /// Enable translucent texture surface for the map.
  /// This allows the map to have a transparent background, useful for overlay scenarios.
  ///
  /// This moves the map into a `TextureView` (MapLibre's `textureMode`) and
  /// makes that view non-opaque, so it brings the same texture layer
  /// composition as [MapLibreMap.useHybridComposition] and adds per-pixel
  /// blending. Set `useHybridComposition` instead when you want the texture
  /// layer with an opaque surface.
  ///
  /// **Available only on Android. Has no effect on iOS or Web.**
  final bool translucentTextureSurface;

  /// Defines the layer order of annotations displayed on map.
  /// Order them from bottom to top. Bottom annotation will be rendered first.
  ///
  /// Any annotation type can only be contained once, so 0 to 4 types.
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
  ///
  /// If `null`, the map style's camera properties (`center`, `zoom`,
  /// `bearing`, `pitch`) are used. If the style also has no camera properties,
  /// the map defaults to center `[0, 0]` at zoom `0`.
  ///
  /// When set, this takes priority over the style's camera properties on all
  /// platforms.
  final CameraPosition? initialCameraPosition;

  /// How long a user has to click the map **on iOS** until a long click is registered.
  /// Has no effect on web or Android. Can not be changed at runtime, only the initial value is used.
  /// If null, the default value of the native MapLibre library / of the OS is used.
  final Duration? iosLongClickDuration;

  /// If true, the map's canvas can be exported to a PNG using map.getCanvas().toDataURL().
  /// This is false by default as a performance optimization.
  /// **Web only** - has no effect on other platforms.
  final bool? webPreserveDrawingBuffer;

  /// True if the map should show a compass when rotated.
  final bool compassEnabled;

  /// True if drag functionality should be enabled.
  ///
  /// Disable to avoid performance issues that from the drag event listeners.
  /// Biggest impact in android
  final bool dragEnabled;

  /// Whether tapping on a feature also triggers the map click event.
  /// Defaults to `false`.
  ///
  /// If `true`, both the feature tap and `onMapClick` events will fire when tapping a feature.
  /// If `false`, only the feature tap event fires, and `onMapClick` is not called.
  final bool featureTapsTriggersMapClick;

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
  /// 4. Passing the raw JSON of the map style.
  final String styleString;

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

  /// True if you want to be notified of map camera movements by the [MapLibreMapController]. Default is false.
  ///
  /// If this is set to true and the user pans/zooms/rotates the map, [MapLibreMapController] (which is a [ChangeNotifier])
  /// will notify it's listeners and you can then get the new [MapLibreMapController].cameraPosition.
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
  /// If this is set to a value other than [MyLocationRenderMode.normal], [myLocationEnabled] needs to be true.
  final MyLocationRenderMode myLocationRenderMode;

  /// True if the MapLibre logo should be shown on the map.
  /// Defaults to false.
  final bool logoEnabled;

  /// Set the position for the Logo
  final LogoViewPosition? logoViewPosition;

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

  /// Tint color for the MapLibre attribution (i) button. Leave it null to keep
  /// the MapLibre SDK's own tint, and set it when that tint does not read well
  /// against your style, for example a light color over a dark style.
  ///
  /// Has no effect on Web, where the attribution control is HTML styled via
  /// CSS.
  final Color? attributionButtonColor;

  /// True if the scale control should be shown on the map.
  /// Defaults to false.
  /// **Web only** - has no effect on other platforms.
  final bool scaleControlEnabled;

  /// Set the position for the Scale Control.
  /// Defaults to [ScaleControlPosition.bottomLeft].
  /// **Web only** - has no effect on other platforms.
  final ScaleControlPosition scaleControlPosition;

  /// Set the unit for the Scale Control.
  /// Defaults to [ScaleControlUnit.metric].
  /// **Web only** - has no effect on other platforms.
  final ScaleControlUnit scaleControlUnit;

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

  /// Called when camera is moving.
  final OnCameraMoveCallback? onCameraMove;

  /// Called when camera movement has ended.
  final OnCameraIdleCallback? onCameraIdle;

  /// Called when map view is entering an idle state, and no more drawing will
  /// be necessary until new data is loaded or there is some interaction with
  /// the map.
  /// * No camera transitions are in progress
  /// * All currently requested tiles have loaded
  /// * All fade/transition animations have completed
  final OnMapIdleCallback? onMapIdle;

  /// Which Android `View` the map renders into, which is what decides how
  /// Flutter embeds it. Ignored on iOS and web.
  ///
  /// Defaults to `false`, and has done since 0.16.0: the map renders into a
  /// `GLSurfaceView`. Flutter cannot redirect a `SurfaceView`'s drawing into a
  /// texture, so it embeds the map through Virtual Display. The map's own
  /// rendering is as direct as Android allows, at the price of Virtual
  /// Display's known limitations around text input, accessibility and z-order.
  ///
  /// Set it to `true` to render into a `TextureView` instead, which is
  /// MapLibre's `textureMode`. Flutter then composites the map as a texture
  /// layer, so the map behaves like a regular widget: Flutter content can paint
  /// over it, and the map itself can be transformed, clipped or animated.
  /// Rendering into a `TextureView` costs more than a `SurfaceView` on every
  /// Android version.
  ///
  /// Despite the name, this does not select Flutter's "Hybrid Composition"
  /// mode. Both values go through `PlatformViewsService.initAndroidView`; what
  /// changes is the native view, and Flutter picks Texture Layer Hybrid
  /// Composition or Virtual Display from there. Apps on Android 14 or newer
  /// with Vulkan can instead opt into Flutter's Hybrid Composition++, which
  /// composites the `SurfaceView` natively and needs no change here. See
  /// https://docs.flutter.dev/platform-integration/android/platform-views
  ///
  /// [MapLibreMap.translucentTextureSurface] also moves the map to a
  /// `TextureView`, and on top of that makes the view non-opaque. Use this flag
  /// when you want the texture layer without the transparency.
  ///
  /// Assign it before the first [MapLibreMap] is built, ideally before
  /// `runApp()`. The mode is fixed once a platform view exists, so changing it
  /// afterwards leaves maps already on screen untouched.
  static bool get useHybridComposition =>
      MapLibreMethodChannel.useHybridComposition;

  static set useHybridComposition(bool useHybridComposition) =>
      MapLibreMethodChannel.useHybridComposition = useHybridComposition;

  /// Where the web implementation loads MapLibre GL JS from.
  ///
  /// Leave it unset and the plugin injects the build it is tested against, so
  /// `web/index.html` needs no `<script>` or `<link>` tag. Assign a
  /// [MapLibreJsSource] to point the plugin at a self-hosted copy
  /// ([MapLibreJsSource.urls]), or to tell it the page loads the library
  /// itself ([MapLibreJsSource.preloaded]).
  ///
  /// Assign it before the first [MapLibreMap] is built; once the library is on
  /// the page, changing it has no effect. Ignored on Android and iOS.
  static MapLibreJsSource? get webLibrarySource => MapLibreJsSource.configured;

  static set webLibrarySource(MapLibreJsSource? value) =>
      MapLibreJsSource.configured = value;

  /// Starts up the map engine before the first [MapLibreMap] is built, so its
  /// initialization overlaps your app's startup instead of delaying the first
  /// map.
  ///
  /// Call it as early as possible, typically in `main()` before `runApp()`.
  /// Safe to call any number of times: after the first call the underlying
  /// initialization is idempotent.
  ///
  /// On Android the gain comes from issuing the channel call early, since the
  /// plugin's global method handler initializes MapLibre on every call. On web
  /// the expensive part is fetching MapLibre GL JS itself, which the plugin
  /// loads at runtime, so this starts that download during start-up rather
  /// than at the first map build.
  ///
  /// ```dart
  /// void main() {
  ///   MapLibreMap.preWarm(); // fire-and-forget
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// If no Flutter binding exists yet, this call creates the default one,
  /// [WidgetsFlutterBinding], because the method channel it uses cannot work
  /// without a binding. In Flutter the first binding created wins, so a test
  /// or app that needs a different binding, such as
  /// `IntegrationTestWidgetsFlutterBinding`, `TestWidgetsFlutterBinding` or a
  /// custom [WidgetsFlutterBinding] subclass, must initialize its own binding
  /// before calling this method; initializing it afterwards fails with
  /// "Binding is already initialized". For the same reason, an app that
  /// creates its binding inside a custom [Zone], for example within
  /// `runZonedGuarded`, should call this method inside that zone too.
  static Future<void> preWarm() {
    // Being called before runApp() is the entire point of this method, and on
    // Android and iOS it reaches native over a method channel, which resolves
    // its messenger through ServicesBinding.instance. Without a binding that
    // getter throws "Binding has not yet been initialized", so following the
    // documented usage above would fail. runApp() is normally what creates the
    // binding, and it has not run yet, so create it here. ensureInitialized is
    // idempotent, so an app that already called it, or that calls runApp()
    // straight after, is unaffected.
    //
    // Skipped on background isolates (no root isolate token): constructing a
    // binding there throws "UI actions are only available on root isolate"
    // and leaves that isolate's binding statics half-initialized. On those
    // isolates MethodChannel routes through BackgroundIsolateBinaryMessenger
    // instead of the binding, so there is nothing to initialize here. The
    // condition mirrors _findBinaryMessenger in the framework's
    // platform_channel.dart.
    if (kIsWeb || ServicesBinding.rootIsolateToken != null) {
      WidgetsFlutterBinding.ensureInitialized();
    }
    return MapLibreGlobalPlatform.instance.preWarm();
  }

  /// Completes once the web build of the map engine, MapLibre GL JS, is on the
  /// page and the `maplibregl` global is usable. On Android and iOS it
  /// completes immediately.
  ///
  /// The plugin loads MapLibre GL JS itself, so the global does not exist at
  /// page parse time and is not guaranteed to exist at the start of `main()`
  /// either. Apps that call into MapLibre GL JS with their own JS interop, for
  /// example to register a custom protocol with `addProtocol` or to set the
  /// RTL text plugin, must await this first:
  ///
  /// ```dart
  /// Future<void> main() async {
  ///   if (kIsWeb) {
  ///     await MapLibreMap.ensureWebLibraryLoaded();
  ///     registerMyProtocol(); // maplibregl is now usable from JS interop
  ///   }
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// Most apps never need to call this. Every [MapLibreMap] awaits the same
  /// future before it builds its map, so the library being loaded is already
  /// guaranteed by the time your own map callbacks run. Awaiting it before
  /// `runApp()`, as above, holds back the first frame until the library has
  /// arrived, which is the right trade only when something has to be
  /// registered globally before any map exists.
  ///
  /// Where the library is loaded from is configured with [webLibrarySource].
  static Future<void> ensureWebLibraryLoaded() =>
      MapLibreGlobalPlatform.instance.ensureLibraryLoaded();

  @override
  State createState() => _MapLibreMapState();
}

class _MapLibreMapState extends State<MapLibreMap> {
  final Completer<MapLibreMapController> _controller =
      Completer<MapLibreMapController>();
  MapLibreMapController? _mapController;

  late MapLibreMapOptions _maplibreMapOptions;
  final MapLibrePlatform _maplibrePlatform = MapLibrePlatform.createInstance();

  @override
  Widget build(BuildContext context) {
    assert(
      widget.annotationOrder.toSet().length == widget.annotationOrder.length,
      "annotationOrder must not have duplicate types",
    );
    final creationParams = <String, dynamic>{
      if (widget.initialCameraPosition != null)
        'initialCameraPosition': widget.initialCameraPosition!.toMap(),
      'styleString': widget.styleString,
      'options': MapLibreMapOptions.fromWidget(widget).toMap(),
      'dragEnabled': widget.dragEnabled,
      if (widget.iosLongClickDuration != null)
        'iosLongClickDurationMilliseconds':
            widget.iosLongClickDuration!.inMilliseconds,
      if (widget.webPreserveDrawingBuffer != null)
        'webPreserveDrawingBuffer': widget.webPreserveDrawingBuffer,
    };
    return _maplibrePlatform.buildView(
      creationParams,
      onPlatformViewCreated,
      widget.gestureRecognizers,
    );
  }

  @override
  void initState() {
    super.initState();
    _maplibreMapOptions = MapLibreMapOptions.fromWidget(widget);
  }

  @override
  void dispose() {
    if (_controller.isCompleted) {
      _mapController?.dispose();
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(MapLibreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newOptions = MapLibreMapOptions.fromWidget(widget);
    final updates = _maplibreMapOptions.updatesMap(newOptions);

    if (updates.isNotEmpty) {
      // Intentionally not awaited: updating map options asynchronously to avoid blocking widget update.
      unawaited(_updateOptions(updates));
    }
    _maplibreMapOptions = newOptions;
  }

  Future<void> _updateOptions(Map<String, dynamic> updates) async {
    if (updates.isEmpty) {
      return;
    }
    final controller = await _controller.future;
    await controller._updateMapOptions(updates);
  }

  Future<void> onPlatformViewCreated(int id) async {
    final controller = MapLibreMapController(
      maplibrePlatform: _maplibrePlatform,
      initialCameraPosition: widget.initialCameraPosition,
      onStyleLoadedCallback: () async {
        if (_controller.isCompleted) {
          widget.onStyleLoadedCallback?.call();
        } else {
          await _controller.future.then(
            (_) => widget.onStyleLoadedCallback?.call(),
          );
        }
      },
      onMapClick: widget.onMapClick,
      onUserLocationUpdated: widget.onUserLocationUpdated,
      onMapLongClick: widget.onMapLongClick,
      onCameraTrackingDismissed: widget.onCameraTrackingDismissed,
      onCameraTrackingChanged: widget.onCameraTrackingChanged,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
      onMapIdle: widget.onMapIdle,
      annotationOrder: widget.annotationOrder,
      annotationConsumeTapEvents: widget.annotationConsumeTapEvents,
    );
    await _maplibrePlatform.initPlatform(id);
    _mapController = controller;
    _controller.complete(controller);
    widget.onMapCreated?.call(controller);
  }
}

/// Configuration options for the MapLibreMap user interface.
///
/// When used to change configuration, null values will be interpreted as
/// "do not change this configuration option".
///
/// This class is exposed only for testing purposes; it is not intended to be
/// used as part of the public API of this library.
@visibleForTesting
class MapLibreMapOptions {
  MapLibreMapOptions({
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
    this.logoEnabled,
    this.logoViewPosition,
    this.logoViewMargins,
    this.compassViewPosition,
    this.compassViewMargins,
    this.attributionButtonPosition,
    this.attributionButtonMargins,
    this.attributionButtonColor,
    this.scaleControlEnabled,
    this.scaleControlPosition,
    this.scaleControlUnit,
    this.locationEnginePlatforms,
    this.locationSource = const PlatformLocationSource(),
    this.foregroundLoadColor,
    this.translucentTextureSurface,
    this.featureTapsTriggersMapClick,
  });

  MapLibreMapOptions.fromWidget(MapLibreMap map)
    : this(
        locationEnginePlatforms: map.locationEnginePlatforms,
        locationSource: map.locationSource,
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
        logoEnabled: map.logoEnabled,
        logoViewPosition: map.logoViewPosition,
        logoViewMargins: map.logoViewMargins,
        compassViewPosition: map.compassViewPosition,
        compassViewMargins: map.compassViewMargins,
        attributionButtonPosition: map.attributionButtonPosition,
        attributionButtonMargins: map.attributionButtonMargins,
        attributionButtonColor: map.attributionButtonColor,
        scaleControlEnabled: map.scaleControlEnabled,
        scaleControlPosition: map.scaleControlPosition,
        scaleControlUnit: map.scaleControlUnit,
        foregroundLoadColor: map.foregroundLoadColor,
        translucentTextureSurface: map.translucentTextureSurface,
        featureTapsTriggersMapClick: map.featureTapsTriggersMapClick,
      );

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

  final bool? logoEnabled;

  final LogoViewPosition? logoViewPosition;

  final Point? logoViewMargins;

  final CompassViewPosition? compassViewPosition;

  final Point? compassViewMargins;

  final AttributionButtonPosition? attributionButtonPosition;

  final Point? attributionButtonMargins;

  final Color? attributionButtonColor;

  final bool? scaleControlEnabled;

  final ScaleControlPosition? scaleControlPosition;

  final ScaleControlUnit? scaleControlUnit;

  final LocationEnginePlatforms? locationEnginePlatforms;

  final LocationSource locationSource;

  final Color? foregroundLoadColor;

  final bool? translucentTextureSurface;

  final bool? featureTapsTriggersMapClick;

  final _gestureGroup = {
    'rotateGesturesEnabled',
    'scrollGesturesEnabled',
    'tiltGesturesEnabled',
    'zoomGesturesEnabled',
    'doubleClickZoomEnabled',
  };

  Map<String, dynamic> toMap() {
    final optionsMap = <String, dynamic>{};

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
    addIfNonNull('logoEnabled', logoEnabled);
    addIfNonNull('logoViewPosition', logoViewPosition?.index);
    addIfNonNull('logoViewMargins', pointToArray(logoViewMargins));
    addIfNonNull('compassViewPosition', compassViewPosition?.index);
    addIfNonNull('compassViewMargins', pointToArray(compassViewMargins));
    addIfNonNull('attributionButtonPosition', attributionButtonPosition?.index);
    addIfNonNull(
      'attributionButtonMargins',
      pointToArray(attributionButtonMargins),
    );
    addIfNonNull('attributionButtonColor', attributionButtonColor?.toARGB32());
    addIfNonNull('scaleControlEnabled', scaleControlEnabled);
    addIfNonNull('scaleControlPosition', scaleControlPosition?.index);
    addIfNonNull('scaleControlUnit', scaleControlUnit?.index);
    addIfNonNull('locationEngineProperties', locationEnginePlatforms?.toList());
    // Convert the location source to a string token at the platform-channel
    // boundary. The token -> behavior mapping (engine vs. app-provided updates)
    // lives only on the native side.
    addIfNonNull('locationSource', switch (locationSource) {
      ManualLocationSource() => 'manual',
      PlatformLocationSource() => 'platform',
    });
    addIfNonNull('foregroundLoadColor', foregroundLoadColor?.toARGB32());
    addIfNonNull('translucentTextureSurface', translucentTextureSurface);
    addIfNonNull('featureTapsTriggersMapClick', featureTapsTriggersMapClick);
    return optionsMap;
  }

  Map<String, dynamic> updatesMap(MapLibreMapOptions newOptions) {
    final prevOptionsMap = toMap();
    final newOptionsMap = newOptions.toMap();

    // if any gesture is updated also all other gestures have to the saved to
    // the update

    final gesturesRequireUpdate = _gestureGroup.any(
      (key) => newOptionsMap[key] != prevOptionsMap[key],
    );

    return newOptionsMap..removeWhere((key, value) {
      if (_gestureGroup.contains(key)) return !gesturesRequireUpdate;
      final oldValue = prevOptionsMap[key];
      if (oldValue is List && value is List) {
        // Use a deep equality check so that nested structures (e.g. the
        // serialized `cameraTargetBounds`, which becomes a list of lists of
        // lists) are compared by value. `listEquals` only compares the
        // top-level elements with `==`, which always reports nested lists
        // as unequal because Dart's `List` does not override `==`.
        return const DeepCollectionEquality().equals(oldValue, value);
      }
      return oldValue == value;
    });
  }
}
