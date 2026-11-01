// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl.dart';

enum AnnotationType { fill, line, circle, symbol }

/// How the map is drawn on Android. Ignored on iOS and web.
///
/// On Android, MapLibre draws the map in a native view ([surface]), and that
/// view is put on screen together with your widgets ([composition]). Keep the
/// default unless the map misbehaves: the
/// [performance guide](https://maplibre.org/flutter-maplibre-gl/advanced/performance/#platform-view-mode-android)
/// says which setting fixes which problem.
@immutable
class AndroidMapView {
  const AndroidMapView({
    this.surface = AndroidMapSurface.surfaceView,
    this.composition = AndroidComposition.flutter,
  });

  /// The native view MapLibre draws into.
  final AndroidMapSurface surface;

  /// Who puts that view on screen with your widgets.
  final AndroidComposition composition;

  @override
  bool operator ==(Object other) =>
      other is AndroidMapView &&
      other.surface == surface &&
      other.composition == composition;

  @override
  int get hashCode => Object.hash(surface, composition);

  @override
  String toString() =>
      'AndroidMapView(surface: $surface, composition: $composition)';
}

/// The native view MapLibre draws the Android map into.
enum AndroidMapSurface {
  /// A [SurfaceView](https://developer.android.com/reference/android/view/SurfaceView), the fastest.
  /// The default.
  surfaceView,

  /// A [TextureView](https://developer.android.com/reference/android/view/TextureView).
  /// Try it if fast camera moves stutter or flash. It draws more slowly.
  textureView,

  /// A transparent [TextureView](https://developer.android.com/reference/android/view/TextureView):
  /// widgets behind the map show through where the style has no background.
  /// It draws more slowly, like [textureView].
  translucentTextureView,
}

/// Who puts the Android map on screen with your widgets.
///
/// If the app enables
/// [Hybrid Composition++](https://maplibre.org/flutter-maplibre-gl/advanced/performance/#hybrid-composition)
/// and the device supports it, Android does it, whatever the value.
enum AndroidComposition {
  /// Flutter draws the map into its own frame, like any widget. The default.
  flutter,

  /// Android places the map next to Flutter's content (Hybrid Composition).
  /// Try it if map updates show up late, only when something else on screen
  /// moves. Flutter renders more slowly while the map is visible.
  hybridComposition,
}

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
    this.hapticFeedbackEnabled = true,
    this.doubleClickZoomEnabled,
    this.dragEnabled = true,
    this.panInertia = PanInertia.normal,
    this.featureTapsTriggersMapClick = false,
    this.symbolPlacementTransitionsEnabled = true,
    this.trackCameraPosition = false,
    this.myLocationEnabled = false,
    this.myLocationTrackingMode = MyLocationTrackingMode.none,
    this.myLocationRenderMode = MyLocationRenderMode.normal,
    this.myLocationStyle,
    this.logoEnabled = false,
    this.logoViewPosition,
    this.logoViewMargins,
    this.compassViewPosition,
    this.compassViewMargins,
    this.attributionEnabled = true,
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
    this.onCameraMoveStarted,
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
    this.androidView,
    @Deprecated(
      'Use androidView: AndroidMapView(surface: '
      'AndroidMapSurface.translucentTextureView) instead',
    )
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

  /// What feeds the map's user-location component (the puck).
  ///
  /// Defaults to [PlatformLocationSource], the device's location engine. Use
  /// [ManualLocationSource] to drive the puck from your own fixes, pushed with
  /// [MapLibreMapController.updateManualLocation]; that mode needs no location
  /// permission and works on Android, iOS and web.
  ///
  /// Only has an effect when [myLocationEnabled] is true, and is read when the
  /// component is activated: changing it later does not re-activate it.
  final LocationSource locationSource;

  /// The color used for the map loading foreground.
  /// Pass a [Color] and it will be converted to ARGB int for the platform.
  ///
  /// **Available only on Android. Has no effect on iOS or Web.**
  final Color? foregroundLoadColor;

  /// How the map is drawn on Android, see [AndroidMapView]. Null keeps the
  /// default. Read on the first build only. Ignored on iOS and web.
  final AndroidMapView? androidView;

  /// `true` draws the Android map into a transparent `TextureView`. Ignored
  /// when [androidView] is set, and on iOS and web.
  @Deprecated(
    'Use androidView: AndroidMapView(surface: '
    'AndroidMapSurface.translucentTextureView) instead',
  )
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
  ///
  /// When a newer style load starts before the annotation managers are set up
  /// for the current one, only the newer load calls it. When the native map
  /// answers the setup with a style-not-ready error, the callback is skipped
  /// for that load (a debug build logs it) and the next style load sets the
  /// managers up and calls it.
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

  /// Whether MapLibre fades labels and symbols in and out as it places them.
  /// Defaults to `true`, MapLibre's own default.
  ///
  /// With transitions on, MapLibre recomputes which symbols are shown at most
  /// once every 300 ms and fades the result in. A symbol whose data has just
  /// changed, such as a feature added to a GeoJSON source, can therefore be
  /// drawn at once, then hidden by the next placement and faded back in: it
  /// flickers. With transitions off, placement runs on every frame and
  /// symbols appear and disappear at once, the frame their data arrives.
  ///
  /// Applies to every symbol on the map, the style's own labels included, and
  /// is kept across style changes. On web it sets the map's symbol fade
  /// duration to 0 while off.
  final bool symbolPlacementTransitionsEnabled;

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

  /// How long the map keeps gliding after the user drags it and lets go while
  /// it is still moving. Defaults to [PanInertia.normal].
  ///
  /// On iOS the same setting also applies to the glide after a pinch or a
  /// rotation.
  final PanInertia panInertia;

  /// True if the map view should respond to tilt gestures.
  final bool tiltGesturesEnabled;

  /// True if the device gives a light vibration when the user rotates the map
  /// back to north. Defaults to `true`.
  ///
  /// **Available only on iOS. Has no effect on Android or Web**, which have
  /// no such option.
  final bool hapticFeedbackEnabled;

  /// Set to true to forcefully disable/enable if map should respond to double
  /// click to zoom.
  ///
  /// This takes presedence over zoomGesturesEnabled. Only supported for web.
  final bool? doubleClickZoomEnabled;

  /// Whether the map reports the camera position. Default is false.
  ///
  /// When true, [onCameraMove] receives the camera position as it moves, and
  /// [MapLibreMapController.cameraPosition] follows it. When false,
  /// [onCameraMove] is never called; [onCameraIdle] still is.
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

  /// The colors of the user-location puck. Null keeps the platform's own
  /// look. It can be changed while the map is shown, and setting it back to
  /// null restores the default look.
  ///
  /// See [MyLocationStyle] for what each color applies to on Android, iOS and
  /// web.
  final MyLocationStyle? myLocationStyle;

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

  /// True if the attribution (i) button should be shown on the map.
  /// Defaults to true.
  ///
  /// It can be changed while the map is shown. On web it is the attribution
  /// control, which comes back at [attributionButtonPosition] when shown
  /// again.
  ///
  /// Most map data and tile licenses, OpenStreetMap's included, require the
  /// attribution to stay visible. An app that hides the button must show the
  /// attribution of its sources somewhere else, for example in its own
  /// overlay or about screen.
  final bool attributionEnabled;

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

  /// Called when the user taps the map, with the point of the map view in
  /// logical pixels and the coordinates under it.
  ///
  /// A tap that lands on an interactive layer is reported as a feature tap
  /// instead, and does not reach this callback unless
  /// [featureTapsTriggersMapClick] is set.
  final OnMapClickCallback? onMapClick;

  /// Called on a long press on Android and iOS, and on a double click on web,
  /// which has no long-press gesture. Same arguments as [onMapClick].
  final OnMapLongClickCallback? onMapLongClick;

  /// While the `myLocationEnabled` property is set to `true`, this method is
  /// called whenever a new location update is received by the map view.
  final OnUserLocationUpdated? onUserLocationUpdated;

  /// Called when the map's camera no longer follows the physical device location, e.g. because the user moved the map
  final OnCameraTrackingDismissedCallback? onCameraTrackingDismissed;

  /// Called when the location tracking mode changes
  final OnCameraTrackingChangedCallback? onCameraTrackingChanged;

  /// Called when the camera starts to move, with whether a gesture of the user
  /// or something else moved it. Also kept in
  /// [MapLibreMapController.cameraMoveReason] until [onCameraIdle].
  final OnCameraMoveStartedCallback? onCameraMoveStarted;

  /// Called with the camera position while the camera moves. The last call
  /// before [onCameraIdle] has the position where it stopped, also for a move
  /// without animation such as `moveCamera`.
  ///
  /// Only called when [trackCameraPosition] is true.
  final OnCameraMoveCallback? onCameraMove;

  /// Called when camera movement has ended. With [trackCameraPosition], read
  /// the final position from [MapLibreMapController.cameraPosition].
  final OnCameraIdleCallback? onCameraIdle;

  /// Called when map view is entering an idle state, and no more drawing will
  /// be necessary until new data is loaded or there is some interaction with
  /// the map.
  /// * No camera transitions are in progress
  /// * All currently requested tiles have loaded
  /// * All fade/transition animations have completed
  final OnMapIdleCallback? onMapIdle;

  /// `true` draws Android maps into a `TextureView`, except maps that set
  /// [androidView]. Despite its name, it never selected Hybrid Composition.
  @Deprecated(
    'Use androidView: AndroidMapView(surface: AndroidMapSurface.textureView) '
    'instead',
  )
  static bool useHybridComposition = false;

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

  /// Starts up the map engine early, so its initialization overlaps app
  /// start-up instead of delaying the first map.
  ///
  /// Call it from `main()`, before `runApp()`, when your **first screen is a
  /// map**. It is not a blanket recommendation: an app whose map lives a few
  /// screens in pays for start-up work its first screen never uses. Calling it
  /// more than once is harmless.
  ///
  /// ```dart
  /// void main() {
  ///   MapLibreMap.preWarm(); // fire-and-forget
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// This initializes the Flutter binding if the app has not done so yet, since
  /// the call needs one before `runApp()` creates it. The first binding created
  /// wins, so an app or test that needs a different one, such as
  /// `IntegrationTestWidgetsFlutterBinding`, must initialize it before calling
  /// this. Likewise, an app that creates its binding inside a custom [Zone],
  /// for example under `runZonedGuarded`, should call this inside that zone.
  static Future<void> preWarm() {
    // On Android and iOS this reaches native over a platform channel, whose
    // messenger comes from ServicesBinding.instance, and being called before
    // runApp() is the whole point of the method, so the binding runApp() would
    // have created does not exist yet. ensureInitialized is idempotent, so
    // doing it here costs an app that already did it nothing.
    //
    // Background isolates are skipped: there platform channels route through
    // BackgroundIsolateBinaryMessenger rather than the binding, and building a
    // binding would throw "UI actions are only available on root isolate" and
    // leave that isolate's binding statics half-initialized. The condition
    // mirrors _findBinaryMessenger in the framework's platform_channel.dart.
    if (kIsWeb || ServicesBinding.rootIsolateToken != null) {
      WidgetsFlutterBinding.ensureInitialized();
    }
    return _global.preWarm();
  }

  /// Completes once MapLibre GL JS is on the page and the `maplibregl` global
  /// is usable. Completes immediately on Android and iOS.
  ///
  /// Most apps never need this: every [MapLibreMap] awaits the same future
  /// before building its map, so the library is already there by the time your
  /// map callbacks run. Await it when your own JS interop has to reach
  /// `maplibregl` before any map exists, for example to register a protocol
  /// with `addProtocol` or to set the RTL text plugin. Awaiting it before
  /// `runApp()`, as below, holds back the first frame until the library has
  /// arrived.
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
  /// Where the library comes from is configured with [webLibrarySource].
  static Future<void> ensureWebLibraryLoaded() => _global.ensureLibraryLoaded();

  @override
  State createState() => _MapLibreMapState();
}

class _MapLibreMapState extends State<MapLibreMap> {
  final Completer<MapLibreMapController> _controller =
      Completer<MapLibreMapController>();
  MapLibreMapController? _mapController;

  late MapLibreMapOptions _maplibreMapOptions;
  final MapLibrePlatform _maplibrePlatform = _createMapLibrePlatform();

  /// Set in [dispose], which also tears the platform down. Creating a map is
  /// asynchronous and can outlive the widget that asked for it, so everything
  /// that runs after an await checks this before touching the platform again.
  bool _disposed = false;

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
      if (widget.androidView != null) 'androidView': widget.androidView,
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
    _disposed = true;
    // Once the controller exists it owns the platform and disposes it for us,
    // also while the map is still being created or when its creation threw.
    // Before that, the platform view was never created: tearing the platform
    // down anyway is what keeps the registered platform view, and on web the
    // map element and its listeners, from outliving the widget.
    final controller = _mapController;
    if (controller != null) {
      controller.dispose();
    } else {
      _maplibrePlatform.dispose();
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
    // The widget was disposed before its platform view was created, and
    // dispose() has already torn the platform down. Wiring it up now would
    // leave a channel handler and controller listeners nobody ever removes.
    if (_disposed) return;
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
      onCameraMoveStarted: widget.onCameraMoveStarted,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
      onMapIdle: widget.onMapIdle,
      annotationOrder: widget.annotationOrder,
      annotationConsumeTapEvents: widget.annotationConsumeTapEvents,
    );
    // The controller listens to the platform from here on, so dispose() must
    // reach it even if the widget goes away before the map is created:
    // otherwise a style that loads meanwhile starts an annotation setup on a
    // controller that never learns the map is gone.
    _mapController = controller;
    // Nobody awaits this method: the platform view factory calls it and drops
    // the future. So a failure here has to reach the completer, or everything
    // waiting on the controller, including onStyleLoadedCallback above, waits
    // for a map that will never arrive. On web the engine throws from here when
    // the browser provides no WebGL context at all.
    try {
      await _maplibrePlatform.initPlatform(id);
    } catch (error, stack) {
      // Reporting a failure nobody can act on would only be an unhandled
      // error: the widget is gone and dispose() has torn the platform down.
      if (!_disposed) _controller.completeError(error, stack);
      return;
    }
    // The widget was disposed while the map was being created, so dispose()
    // has already torn the platform down. Publishing the controller now would
    // hand out one whose native map no longer exists, and the style-loaded
    // callback it wires up would then fail against it, which surfaces as an
    // unhandled `STYLE_NOT_READY` out of the annotation managers.
    if (_disposed) return;
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
    this.panInertia,
    this.hapticFeedbackEnabled,
    this.trackCameraPosition,
    this.myLocationEnabled,
    this.myLocationTrackingMode,
    this.myLocationRenderMode,
    this.myLocationStyle,
    this.logoEnabled,
    this.logoViewPosition,
    this.logoViewMargins,
    this.compassViewPosition,
    this.compassViewMargins,
    this.attributionEnabled,
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
    this.symbolPlacementTransitionsEnabled,
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
        panInertia: map.panInertia,
        hapticFeedbackEnabled: map.hapticFeedbackEnabled,
        myLocationEnabled: map.myLocationEnabled,
        myLocationTrackingMode: map.myLocationTrackingMode,
        myLocationRenderMode: map.myLocationRenderMode,
        myLocationStyle: map.myLocationStyle ?? const MyLocationStyle(),
        logoEnabled: map.logoEnabled,
        logoViewPosition: map.logoViewPosition,
        logoViewMargins: map.logoViewMargins,
        compassViewPosition: map.compassViewPosition,
        compassViewMargins: map.compassViewMargins,
        attributionEnabled: map.attributionEnabled,
        attributionButtonPosition: map.attributionButtonPosition,
        attributionButtonMargins: map.attributionButtonMargins,
        attributionButtonColor: map.attributionButtonColor,
        scaleControlEnabled: map.scaleControlEnabled,
        scaleControlPosition: map.scaleControlPosition,
        scaleControlUnit: map.scaleControlUnit,
        foregroundLoadColor: map.foregroundLoadColor,
        // Still forwarded, as native reads it for the deprecated flag.
        // ignore: deprecated_member_use_from_same_package
        translucentTextureSurface: map.translucentTextureSurface,
        featureTapsTriggersMapClick: map.featureTapsTriggersMapClick,
        symbolPlacementTransitionsEnabled:
            map.symbolPlacementTransitionsEnabled,
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

  final PanInertia? panInertia;
  final bool? hapticFeedbackEnabled;

  final bool? trackCameraPosition;

  final bool? myLocationEnabled;

  final MyLocationTrackingMode? myLocationTrackingMode;

  final MyLocationRenderMode? myLocationRenderMode;

  final MyLocationStyle? myLocationStyle;

  final bool? logoEnabled;

  final LogoViewPosition? logoViewPosition;

  final Point? logoViewMargins;

  final CompassViewPosition? compassViewPosition;

  final Point? compassViewMargins;

  final bool? attributionEnabled;

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

  final bool? symbolPlacementTransitionsEnabled;

  final _gestureGroup = {
    'rotateGesturesEnabled',
    'scrollGesturesEnabled',
    'tiltGesturesEnabled',
    'zoomGesturesEnabled',
    'doubleClickZoomEnabled',
    'panInertia',
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
    addIfNonNull('panInertia', panInertia?.index);
    addIfNonNull('hapticFeedbackEnabled', hapticFeedbackEnabled);

    addIfNonNull('trackCameraPosition', trackCameraPosition);
    addIfNonNull('myLocationEnabled', myLocationEnabled);
    addIfNonNull('myLocationTrackingMode', myLocationTrackingMode?.index);
    addIfNonNull('myLocationRenderMode', myLocationRenderMode?.index);
    addIfNonNull('myLocationStyle', myLocationStyle?.toJson());
    addIfNonNull('logoEnabled', logoEnabled);
    addIfNonNull('logoViewPosition', logoViewPosition?.index);
    addIfNonNull('logoViewMargins', pointToArray(logoViewMargins));
    addIfNonNull('compassViewPosition', compassViewPosition?.index);
    addIfNonNull('compassViewMargins', pointToArray(compassViewMargins));
    addIfNonNull('attributionEnabled', attributionEnabled);
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
    // By name: Android and iOS map it to PgLocationSource, web to its own
    // setting.
    addIfNonNull('locationSource', switch (locationSource) {
      ManualLocationSource() => 'manual',
      PlatformLocationSource() => 'platform',
    });
    addIfNonNull('foregroundLoadColor', foregroundLoadColor?.toARGB32());
    addIfNonNull('translucentTextureSurface', translucentTextureSurface);
    addIfNonNull('featureTapsTriggersMapClick', featureTapsTriggersMapClick);
    addIfNonNull(
      'symbolPlacementTransitionsEnabled',
      symbolPlacementTransitionsEnabled,
    );
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
      if ((oldValue is List && value is List) ||
          (oldValue is Map && value is Map)) {
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
