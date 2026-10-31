part of '../maplibre_gl_web.dart';

/// A feature of a GeoJSON source as maplibre-gl-js holds it, with the text of
/// its id.
typedef _SourceFeature = ({String? id, JSAny? feature});

/// The [MapLibrePlatform] of web, on maplibre-gl-js.
///
/// Its errors carry the codes and messages of Android and iOS. What
/// maplibre-gl-js reports only through an error event, or accepts silently,
/// is checked before the call and thrown.
class MapLibreMapController extends MapLibrePlatform
    implements MapLibreMapOptionsSink {
  late web.HTMLDivElement _mapElement;

  late Map<String, dynamic> _creationParams;
  late MapLibreMap _map;

  /// Whether [_map] has been assigned. [initPlatform] can fail before it is,
  /// now that it loads maplibre-gl-js first, and [dispose] still runs after
  /// that: reading a `late` field that was never written throws.
  bool _mapCreated = false;
  final _featureDrag = FeatureDragTracker();
  bool _dragEnabled = true;

  /// Listens on the window for the release of a press on a draggable feature,
  /// while one is in progress: released outside the map, it never reaches the
  /// map's own `mouseup`.
  JSFunction? _windowMouseUp;
  bool _featureTapsTriggersMapClick = false;

  /// The features of each GeoJSON source whose data [addGeoJsonSource],
  /// [setGeoJsonSource] or [editGeoJsonSource] set, as maplibre-gl-js holds
  /// them, with the text of their id, for [setFeatureForGeoJsonSource].
  final _addedFeaturesByLayer = <String, List<_SourceFeature>>{};
  final _hoveredFeatureIdsByLayer = <String, List<dynamic>>{};

  /// Where the pointer was at the last hover event, for the leave events a
  /// removed layer can no longer fire itself.
  ({Point<double> point, LatLng latLng})? _lastHoverPosition;
  Set<String>? _assetManifest;
  Future<Set<String>>? _assetManifestRead;

  final _interactiveFeatureLayerIds = <String>{};
  final _mapSubscriptions = <Subscription>[];

  bool _trackCameraPosition = false;
  GeolocateControl? _geolocateControl;
  bool _enableHighAccuracy = false;
  int _maximumAge = 0;
  int _timeout = 0;
  bool _trackUserLocation = false;
  LatLng? _myLastLocation;

  // Manual (app-provided) location source. When `locationSource` is 'manual'
  // and `myLocationEnabled` is true, web renders its own puck (see
  // [ManualLocationPuck]) instead of the browser GeolocateControl, which cannot
  // be fed an arbitrary position. This controller only tracks the two flags and
  // the requested tracking mode; the puck itself owns its rendering state and
  // is created lazily on the first fix.
  bool _manualLocationSource = false;
  bool _myLocationEnabled = false;
  int _manualTrackingMode = 0;
  ManualLocationPuck? _manualPuck;
  ManualLocationUpdate? _lastManualFix;
  LocationPuckStyler? _locationPuckStyler;

  String? _navigationControlPosition;
  NavigationControl? _navigationControl;
  AttributionControl? _attributionControl;
  bool _attributionEnabled = true;
  AttributionButtonPosition _attributionButtonPosition =
      AttributionButtonPosition.bottomRight;
  ScaleControl? _scaleControl;
  String? _scaleControlPosition;
  Timer? lastResizeObserverTimer;

  /// Completes the [animateCamera] or [easeCamera] call whose animation is
  /// still running.
  Completer<bool>? _pendingCameraAnimation;

  /// Numbers each [_runCameraAnimation] call, to tell its events apart.
  int _cameraAnimationCount = 0;

  /// Set while [_stopCamera] runs: a moveend then sends no onCameraIdle.
  bool _holdingCameraIdle = false;

  /// Whether a moveend came while [_holdingCameraIdle] was set.
  bool _cameraIdleHeld = false;

  /// Set while [_startCameraMove] runs: the first movestart then sends no
  /// onCameraMoveStarted.
  bool _skipCameraMoveStarted = false;

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    _creationParams = creationParams;
    _registerViewFactory(onPlatformViewCreated, hashCode);
    return HtmlElementView(
      viewType: 'plugins.flutter.io/maplibre_gl_$hashCode',
    );
  }

  @override
  void dispose() {
    // The map goes away mid-animation: answer the waiting camera call.
    _cancelCameraAnimation();
    _cancelSnapshot(
      'MAP_DISPOSED',
      'The map was disposed before the snapshot was ready.',
    );
    _removeManualPuck();
    _forgetImageUrls();
    for (final sub in _mapSubscriptions) {
      sub.unsubscribe();
    }
    _mapSubscriptions.clear();
    _stopListeningForReleaseOutside();
    if (_mapCreated) {
      _map.clearMissingStyleImageHandler();
      _map.remove();
    }
    super.dispose();
  }

  void _registerViewFactory(Function(int) callback, int identifier) {
    ui_web.platformViewRegistry.registerViewFactory(
      'plugins.flutter.io/maplibre_gl_$identifier',
      (int viewId) {
        _mapElement =
            (web.document.createElement('div') as web.HTMLDivElement)
              ..style.position = 'absolute'
              ..style.top = '0'
              ..style.bottom = '0'
              ..style.height = '100%'
              ..style.width = '100%';
        callback(viewId);
        return _mapElement;
      },
    );
  }

  @override
  Future<void> initPlatform(int id) async {
    // Every @JS binding in this package resolves its name at call time, so
    // nothing below works until maplibre-gl-js is on the page.
    await MapLibreJsLoader.ensureLoaded();

    final camera =
        _creationParams['initialCameraPosition'] as Map<String, dynamic>?;
    final styleString = await _sanitizeStyleObject(
      _creationParams['styleString'],
    );
    _dragEnabled = _creationParams['dragEnabled'] ?? true;

    // Reported here rather than left to the caller: this future is not awaited
    // anywhere, so an error out of it would only ever be an unhandled one, and
    // the map's own construction can throw. maplibre-gl-js 6.7 and later throw
    // a GPUInitializationError when they cannot get a WebGL2 context, and 5,
    // the build the docs send a WebGL1 only browser to, throws when it cannot
    // get any WebGL context.
    try {
      _map = MapLibreMap(
        MapOptions(
          container: _mapElement,
          center:
              (camera != null)
                  ? LngLat(camera['target'][1], camera['target'][0])
                  : null,
          zoom: camera?['zoom'],
          bearing: camera?['bearing'],
          pitch: camera?['tilt'],
          style: styleString,
          preserveDrawingBuffer: _creationParams['webPreserveDrawingBuffer'],
          attributionControl: false, //avoid duplicate control
        ),
      );
    } catch (error, stack) {
      // Says whether WebGL is why, and what to do on a WebGL1 only browser.
      _reportRendererDiagnostic(
        () => webGlDiagnostic(
          hasRenderer: false,
          probe: canCreateWebGlContext,
        ),
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'maplibre_gl_web',
          context: ErrorDescription(
            'while creating the map. A browser without the WebGL context the '
            'library needs fails here, and so does a library build that cannot '
            'read the style. The map stays empty',
          ),
        ),
      );
      rethrow;
    }
    _mapCreated = true;
    _reportRendererDiagnostic(() => mapRendererDiagnostic(_map));
    _mapSubscriptions.add(_map.on('style.load', _onStyleLoaded));
    _mapSubscriptions.add(_map.on('click', _onMapClick));
    // long click not available in web, so it is mapped to double click
    _mapSubscriptions.add(_map.on('dblclick', _onMapLongClick));
    _mapSubscriptions.add(_map.on('movestart', _onCameraMoveStarted));
    _mapSubscriptions.add(_map.on('move', _onCameraMove));
    _mapSubscriptions.add(_map.on('moveend', _onCameraIdle));
    _mapSubscriptions.add(_map.on('idle', _onMapIdle));
    _mapSubscriptions.add(_map.on('resize', (_) => _onMapResize()));
    // Null on a library that takes a resolver, which goes away with
    // clearMissingStyleImageHandler in dispose; a subscription on version 5,
    // where the listener is the only path.
    final missingStyleImages = _map.setMissingStyleImageHandler(
      _loadFromAssets,
    );
    if (missingStyleImages != null) _mapSubscriptions.add(missingStyleImages);
    if (_dragEnabled) {
      // Registered before any layer's mousedown, so it runs first and a press
      // on a draggable feature starts after the leftovers are cleared.
      _mapSubscriptions.add(_map.on('mousedown', (_) => _endPress()));
      _mapSubscriptions.add(_map.on('mouseup', _onMouseUp));
      _mapSubscriptions.add(_map.on('mousemove', _onPointerMove));
      // The same for a finger. A second finger ends the drag at the last
      // position and the map takes over the pinch, as on Android and iOS.
      _mapSubscriptions.add(_map.on('touchstart', (_) => _endPress()));
      _mapSubscriptions.add(_map.on('touchmove', _onTouchMove));
      _mapSubscriptions.add(_map.on('touchend', _onTouchEnd));
      _mapSubscriptions.add(_map.on('touchcancel', (_) => _endPress()));
    }
    // Always listen to mousemove for general map mouse move events
    _mapSubscriptions.add(_map.on('mousemove', _onMapMouseMove));

    _initResizeObserver();

    final options = _creationParams['options'] ?? {};
    Convert.interpretMapLibreMapOptions(options, this, ignoreStyle: true);
    // Options without attribution settings still get the control, at the
    // default position.
    if (_attributionControl == null) _updateAttributionButton();
  }

  /// Says why the map will stay blank when WebGL is the reason.
  ///
  /// maplibre-gl-js 6.7 and later throw from their constructor without WebGL2.
  /// 6.0 to 6.6, which an app can still load through [MapLibreJsSource], only
  /// fire an `error` from inside the constructor, too early for
  /// [MapLibreMap.on] to catch, and leave the map without a renderer, so
  /// without this the map is just empty.
  ///
  /// Each distinct cause is reported once per session, through
  /// [FlutterError.reportError] rather than the silenceable [debugPrint]. Nothing
  /// here may throw: this runs in a future nobody awaits, so an error would turn a
  /// blank map into one that never finishes being created.
  void _reportRendererDiagnostic(String? Function() diagnose) {
    try {
      final diagnostic = diagnose();
      if (diagnostic == null) return;
      if (!_reportedRendererDiagnostics.add(diagnostic)) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: diagnostic,
          library: 'maplibre_gl_web',
          context: ErrorDescription('while creating the map'),
        ),
      );
    } catch (_) {
      // A diagnostic that cannot be produced is not worth a broken map.
    }
  }

  static final _reportedRendererDiagnostics = <String>{};

  /// Forgets what has been reported, so one test cannot silence the next.
  @visibleForTesting
  static void debugResetRendererDiagnostics() =>
      _reportedRendererDiagnostics.clear();

  void _initResizeObserver() {
    final resizeObserver = web.ResizeObserver(
      ((JSAny entries, JSAny observer) {
        // The resize observer might be called a lot of times when the user resizes the browser window with the mouse for example.
        // Due to the fact that the resize call is quite expensive it should not be called for every triggered event but only the last one, like "onMoveEnd".
        // But because there is no event type for the end, there is only the option to spawn timers and cancel the previous ones if they get overwritten by a new event.
        lastResizeObserverTimer?.cancel();
        lastResizeObserverTimer = Timer(const Duration(milliseconds: 50), () {
          _onMapResize();
        });
      }).toJS,
    );
    resizeObserver.observe(_mapElement);
  }

  /// The declared assets, read once.
  ///
  /// The in-flight read is kept, not just the result: maplibre-gl-js 6 asks for
  /// every image a tile is missing at once, so the first batch would otherwise
  /// read and parse the manifest once per image, with the renderer waiting on
  /// all of them.
  Future<Set<String>> _loadAssetManifest() {
    final loaded = _assetManifest;
    if (loaded != null) return Future.value(loaded);
    return _assetManifestRead ??= _readAssetManifest();
  }

  Future<Set<String>> _readAssetManifest() async {
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      _assetManifest = assets.toSet();
    } catch (_) {
      // If the manifest can't be read, assume no declared assets
      _assetManifest = <String>{};
    }

    _assetManifestRead = null;
    return _assetManifest!;
  }

  /// Supplies an image the style asks for but does not have.
  ///
  /// Nothing may escape: since maplibre-gl-js 6 awaits this future inside one
  /// `Promise.all` for the whole batch of images a tile asks for, and catches
  /// nothing itself, a single error here would leave every image in that batch
  /// unresolved and the tile's symbols undrawn. Where the old
  /// `styleimagemissing` listener could drop an error harmlessly, this one has
  /// to swallow it on purpose, so the style keeps its missing image and the rest
  /// of the batch still arrives.
  Future<void> _loadFromAssets(String imagePath) async {
    try {
      // Check if the image is already added
      if (_map.hasImage(imagePath)) return;

      // Check if the image is declared in the assets loaded
      final manifest = await _loadAssetManifest();
      if (!manifest.contains(imagePath) &&
          !manifest.contains('assets/$imagePath')) {
        return;
      }

      // Sized like Image.asset: the 2.0x or 3.0x variant AssetImage picks for
      // this screen, at its own ratio. A file without variants is 1x, which is
      // the addImage default here. AssetIcons on Android and iOS do the same.
      final key = await AssetImage(imagePath).obtainKey(
        ImageConfiguration(devicePixelRatio: web.window.devicePixelRatio),
      );
      final bytes = await rootBundle.load(key.name);
      await addImage(imagePath, bytes.buffer.asUint8List(), false, key.scale);
    } catch (_) {
      // Ignore, so MapLibre can continue without the image.
    }
  }

  void _onMouseDown(Event e, String? layerId) {
    if (_pressDraggableFeature(e)) _listenForReleaseOutside();
  }

  void _onTouchStart(Event e, String? layerId) {
    // With a second finger the touch is the map's pinch, not a new drag.
    if (_touchEvent(e).touches.length == 1) _pressDraggableFeature(e);
  }

  /// Starts a press on the draggable feature under [e], if there is one, and
  /// keeps the map from panning under it. Nothing is reported yet: the press
  /// is a click until the pointer moves past the drag threshold, as on Android
  /// and iOS.
  bool _pressDraggableFeature(Event e) {
    if (e.features.isEmpty) return false;
    final isDraggable = e.features.first.getProperty('draggable');
    if (isDraggable == null || !isDraggable) return false;
    e.preventDefault();
    final id = plainFeatureId(e.features.first.id);
    if (id == null) return false;
    _featureDrag.down(id, _eventPoint(e));
    return true;
  }

  void _onMouseUp(Event e) {
    _stopListeningForReleaseOutside();
    final payload = _featureDrag.up(_eventPoint(e), _eventLatLng(e));
    if (payload != null) onFeatureDraggedPlatform(payload);
    _map.getCanvas().style.cursor = '';
  }

  /// Ends a press whose release did not reach the map: released outside it,
  /// or lost altogether and found by the next press.
  void _endPress() {
    _stopListeningForReleaseOutside();
    if (!_featureDrag.isPressed) {
      _featureDrag.pointerDown();
      return;
    }
    final payload = _featureDrag.upOutside();
    _map.getCanvas().style.cursor = '';
    if (payload != null) onFeatureDraggedPlatform(payload);
  }

  void _listenForReleaseOutside() {
    if (_windowMouseUp != null) return;
    final listener = ((web.Event _) => _endPress()).toJS;
    _windowMouseUp = listener;
    web.window.addEventListener('mouseup', listener);
  }

  void _stopListeningForReleaseOutside() {
    final listener = _windowMouseUp;
    if (listener == null) return;
    _windowMouseUp = null;
    web.window.removeEventListener('mouseup', listener);
  }

  void _onPointerMove(Event e) {
    final payload = _featureDrag.move(_eventPoint(e), _eventLatLng(e));
    if (payload == null) return;
    if (payload['eventType'] == 'start') {
      _map.getCanvas().style.cursor = 'grabbing';
    }
    onFeatureDraggedPlatform(payload);
  }

  void _onTouchMove(Event e) {
    if (!_featureDrag.isPressed) return;
    final touch = _touchEvent(e);
    // A second finger that landed off the map ends the drag too.
    if (touch.touches.length > 1) {
      _endPress();
      return;
    }
    _onPointerMove(e);
    // Keeps the browser from scrolling the page under the dragged feature.
    if (_featureDrag.isDragging) touch.preventDefault();
  }

  void _onTouchEnd(Event e) {
    final payload = _featureDrag.up(_eventPoint(e), _eventLatLng(e));
    if (payload == null) return;
    // The browser sends no mouse events and no click after the drag, so no
    // tap follows it, as on Android and iOS.
    _touchEvent(e).preventDefault();
    _map.getCanvas().style.cursor = '';
    onFeatureDraggedPlatform(payload);
  }

  /// The browser's touch event behind the map's touch event [e].
  static web.TouchEvent _touchEvent(Event e) => (e.jsObject as JSObject)
      .getProperty<web.TouchEvent>('originalEvent'.toJS);

  static Point<double> _eventPoint(Event e) =>
      Point<double>(e.point.x.toDouble(), e.point.y.toDouble());

  static LatLng _eventLatLng(Event e) =>
      LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble());

  _onMapMouseMove(Event e) {
    // Simple mouse move event - just provides position
    onMapMouseMovePlatform({
      'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
      'latLng': LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble()),
    });
  }

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    Convert.interpretMapLibreMapOptions(optionsUpdate, this);
    return _getCameraPosition();
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    _checkCameraUpdate(cameraUpdate);
    final cameraOptions = Convert.toCameraOptions(cameraUpdate, _map);

    // Use the existing CameraOptions wrapper which has proper WASM-compatible accessors
    final around = cameraOptions.around;
    final bearing = cameraOptions.bearing;
    final center = cameraOptions.center;
    final pitch = cameraOptions.pitch;
    final zoom = cameraOptions.zoom;

    // true once the camera is on target, false if something cuts it short,
    // as on Android.
    return _runCameraAnimation(
      (eventData) => _map.flyTo({
        if (around != null) 'around': around.jsObject,
        if (bearing != null) 'bearing': bearing,
        if (center != null) 'center': center.jsObject,
        if (pitch != null) 'pitch': pitch,
        if (zoom != null) 'zoom': zoom,
        if (duration != null) 'duration': duration.inMilliseconds,
      }, eventData),
    );
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    _checkCameraUpdate(cameraUpdate);
    final cameraOptions = Convert.toCameraOptions(cameraUpdate, _map);
    _cancelCameraAnimation();
    final idleHeld = _stopCamera();
    _startCameraMove(idleHeld, () => _map.jumpTo(cameraOptions));
    return true;
  }

  /// Stops the camera motion in progress, such as the inertia after a fling
  /// or an animation, for a camera call that takes over from it. Android
  /// carries on into the new move and sends onCameraIdle once, when the
  /// camera settles, but maplibre-gl-js ends the stopped motion with a
  /// moveend. So that moveend sends no onCameraIdle here: this returns
  /// whether one was held back, to pass to [_startCameraMove].
  ///
  /// A gesture stopped mid-way ends with no moveend, so nothing is held.
  bool _stopCamera() {
    _cameraIdleHeld = false;
    _holdingCameraIdle = true;
    try {
      _map.stop();
    } finally {
      _holdingCameraIdle = false;
    }
    return _cameraIdleHeld;
  }

  /// Runs [move], a camera change that starts with a movestart. If
  /// [_stopCamera] held back an onCameraIdle, the app already heard
  /// onCameraMoveStarted for the motion [move] continues, so its movestart
  /// sends none. If [move] throws or starts no motion, the held onCameraIdle
  /// goes out instead, as no moveend of its own will.
  void _startCameraMove(bool idleHeld, void Function() move) {
    if (!idleHeld) {
      move();
      return;
    }
    var started = false;
    _skipCameraMoveStarted = true;
    try {
      move();
      started = !_skipCameraMoveStarted;
    } finally {
      _skipCameraMoveStarted = false;
      if (!started) _onCameraIdle(null);
    }
  }

  /// Throws `INVALID_ARGUMENT`, as Android and iOS do, for an update with a
  /// value that is NaN or infinite. maplibre-gl-js would throw an error of its
  /// own or move to a camera it cannot draw.
  static void _checkCameraUpdate(CameraUpdate update) {
    final error = checks.cameraUpdateError(update);
    if (error != null) throw checks.invalidArgument(error);
  }

  /// Starts the camera animation [start] begins and completes when it ends:
  /// true once the camera arrived, false when anything else stops it first,
  /// as on Android. [start] must pass the event data it gets to
  /// `easeTo` or `flyTo`.
  Future<bool> _runCameraAnimation(
    void Function(Map<String, Object> eventData) start,
  ) {
    // An animation still running is cut short by this one, which Android
    // reports as a cancel. Stopping it first also fires its moveend now,
    // before the listeners below exist, so that moveend cannot complete this
    // call.
    _cancelCameraAnimation();
    final idleHeld = _stopCamera();

    final id = ++_cameraAnimationCount;
    // maplibre-gl-js copies the event data onto every move and moveend this
    // animation fires, which tells them apart from the moveend that
    // setMinZoom, setMaxZoom or a gesture fire while it keeps running.
    bool isThisAnimation(Event e) =>
        (e.jsObject as JSObject)
            .getProperty<JSNumber?>(_cameraAnimationKey.toJS)
            ?.toDartInt ==
        id;

    // maplibre-gl-js ends an animation with the same moveend whether it ran
    // its course or something stopped it (Camera._stop runs _afterEase in
    // both cases), and many interruptions leave no handler active: the
    // keyboard, double click and NavigationControl start an easeTo of their
    // own, and the handler manager calls stop(true) before any of them. What
    // differs is when it fires. On arrival, Camera._renderFrameCallback
    // applies the last frame, which fires a move, and calls stop() right
    // away; with no duration, Camera._ease does the same synchronously. An
    // interruption runs later: from an input event, a timer, a geolocation
    // update or a call of the app, all in a task of their own, or from a
    // move listener registered before the one below, which runs before it
    // flags the frame. So the moveend reports arrival only when this
    // animation's move ran in the same synchronous stretch, which a
    // microtask closes.
    var onLastFrame = false;
    final arrival = Completer<bool>();
    _pendingCameraAnimation = arrival;
    late final Subscription moves;
    late final Subscription end;
    void detach() {
      moves.unsubscribe();
      end.unsubscribe();
      if (identical(_pendingCameraAnimation, arrival)) {
        _pendingCameraAnimation = null;
      }
    }

    moves = _map.on('move', (Event e) {
      if (!isThisAnimation(e)) return;
      onLastFrame = true;
      scheduleMicrotask(() => onLastFrame = false);
    });
    end = _map.on('moveend', (Event e) {
      if (!isThisAnimation(e)) return;
      detach();
      if (!arrival.isCompleted) arrival.complete(onLastFrame);
    });

    try {
      _startCameraMove(idleHeld, () => start({_cameraAnimationKey: id}));
    } catch (_) {
      // No moveend is coming: drop the listeners and the pending call, so
      // the next camera call does not answer this one.
      detach();
      if (!arrival.isCompleted) arrival.complete(false);
      rethrow;
    }
    return arrival.future;
  }

  /// The event data key [_runCameraAnimation] marks its events with.
  static const _cameraAnimationKey = 'flutterMapLibreCameraAnimation';

  /// Completes the camera animation still running, if any, with false. Call
  /// it before anything that moves the camera, since maplibre-gl-js stops a
  /// running animation on every camera change.
  void _cancelCameraAnimation() {
    final pending = _pendingCameraAnimation;
    _pendingCameraAnimation = null;
    if (pending != null && !pending.isCompleted) pending.complete(false);
  }

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async {
    setMyLocationTrackingMode(myLocationTrackingMode.index);
  }

  @override
  Future<bool> setTrackingCameraOptions({
    required double tilt,
    Duration? duration,
  }) async {
    // Neither thing that follows the user on web can be pitched while it does so:
    // `GeolocateControl` drops its follow lock on any programmatic camera change,
    // which this class forwards as onCameraTrackingChanged(none), and the manual
    // puck ([ManualLocationPuck]) only exists on manual-source maps. So report it
    // rather than pretend, as feature state does on iOS.
    throw UnsupportedError(
      'setTrackingCameraOptions is not available on web because maplibre-gl-js '
      'has no location component, and its GeolocateControl stops following the '
      'user on any programmatic camera change. Tracking camera options are '
      'supported on Android and iOS. A pitch set before tracking starts does '
      'survive on web, since the control never writes the pitch itself.',
    );
  }

  @override
  Future<void> setManualLocation(ManualLocationUpdate update) async {
    // The one check Android and iOS make too.
    if (!_manualLocationSource) {
      throw PlatformException(
        code: 'MANUAL_LOCATION_SOURCE_DISABLED',
        message:
            'Manual locations require locationSource: ManualLocationSource().',
      );
    }
    _myLastLocation = update.target;
    // Kept so the puck shows up here when myLocationEnabled turns on, also
    // after it was toggled off, which disposes the puck.
    _lastManualFix = update;
    // While myLocationEnabled is off the puck stays hidden and, as on Android
    // and iOS, no update is reported.
    if (!_myLocationEnabled) return;

    // On web, manual mode renders its own puck (no native engine, no
    // GeolocateControl); see [ManualLocationPuck]. It is created lazily on
    // the first fix (a maplibre Marker crashes if added without a position),
    // so this also builds it as needed.
    _showManualPuck();
    _reportManualFix(update);
  }

  /// Reports [update] through onUserLocationUpdated, the path engine updates
  /// take on the native platforms.
  void _reportManualFix(ManualLocationUpdate update) {
    // The wire payload uses `position: [lat, lng]`.
    final map = update.toMap();
    final position = (map['position'] as List).cast<num>();
    final latLng = LatLng(position[0].toDouble(), position[1].toDouble());
    final horizontalAccuracy = (map['horizontalAccuracy'] as num?)?.toDouble();
    final verticalAccuracy = (map['verticalAccuracy'] as num?)?.toDouble();
    final altitude = (map['altitude'] as num?)?.toDouble();
    final bearing = (map['bearing'] as num?)?.toDouble();
    final speed = (map['speed'] as num?)?.toDouble();
    final timestampMs = map['timestamp'] as int;
    onUserLocationUpdatedPlatform(
      UserLocation(
        position: latLng,
        altitude: altitude,
        bearing: bearing,
        speed: speed,
        horizontalAccuracy: horizontalAccuracy,
        verticalAccuracy: verticalAccuracy,
        heading: null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      ),
    );
  }

  /// Shows the puck at the last fix pushed via [setManualLocation], if there
  /// has been one. No-op before the first fix, since a maplibre Marker cannot
  /// be added without a position.
  void _showManualPuck() {
    final fix = _lastManualFix;
    if (fix == null) return;
    _ensureManualPuck().update(
      fix.target,
      accuracyMeters: fix.horizontalAccuracy,
      bearing: fix.bearing,
    );
  }

  /// Lazily creates the manual-location puck, seeding it with the current
  /// tracking mode. The puck itself defers building its markers until the first
  /// position is pushed.
  ManualLocationPuck _ensureManualPuck() {
    // _onCameraTrackingChanged writes _trackUserLocation itself, the same way
    // the GeolocateControl path reaches it, so the flag has one writer.
    return _manualPuck ??= ManualLocationPuck(
      _map,
      onTrackingChanged: _onCameraTrackingChanged,
    )..setTrackingMode(_manualTrackingMode);
  }

  /// Tears down the manual puck, if any.
  void _removeManualPuck() {
    _manualPuck?.dispose();
    _manualPuck = null;
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {
    setMapLanguage(ui.PlatformDispatcher.instance.locale.languageCode);
  }

  @override
  Future<void> setMapLanguage(String language) async {
    final layers = _map.getLayers();

    final languageRegex = RegExp("(name:[a-z]+)");

    final symbolLayers = layers.where((layer) => layer.type == "symbol");

    for (final layer in symbolLayers) {
      final dynamic properties = _map.getLayoutProperty(layer.id, 'text-field');

      if (properties == null) {
        continue;
      }

      // We could skip the current iteration, whenever there is not current language.
      if (!languageRegex.hasMatch(properties.toString())) {
        continue;
      }

      final newProperties = [
        "coalesce",
        ["get", "name:$language"],
        ["get", "name:latin"],
        ["get", "name"],
      ];

      _map.setLayoutProperty(layer.id, 'text-field', newProperties);
    }
  }

  // MapLibre collects no telemetry, so there is nothing to switch.
  @override
  Future<void> setTelemetryEnabled(bool enabled) async {}

  @override
  Future<bool> getTelemetryEnabled() async => false;

  @override
  Future<void> setMaximumFps(int fps) async {
    // Web implementation: MapLibre GL JS doesn't have direct FPS control
    // We can implement this by controlling render frequency if needed
    print('setMaximumFps not fully supported in web, fps: $fps');
    // For future implementation, we could use requestAnimationFrame throttling
  }

  @override
  Future<void> forceOnlineMode() async {
    // Web implementation: Force online mode
    // In web, we can ensure network requests are enabled
    print('forceOnlineMode called in web');
    // This is mostly a no-op in web as it's always online
  }

  @override
  Future<void> pauseMap() async {
    // No-op on web.
  }

  @override
  Future<void> resumeMap() async {
    // No-op on web.
  }

  @override
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  }) async {
    _checkCameraUpdate(cameraUpdate);
    final cameraOptions = Convert.toCameraOptions(cameraUpdate, _map);
    final around = cameraOptions.around;
    final bearing = cameraOptions.bearing;
    final center = cameraOptions.center;
    final pitch = cameraOptions.pitch;
    final zoom = cameraOptions.zoom;
    final easing = resolveEasing(interpolation);

    // true once the camera is on target, as on Android and iOS.
    return _runCameraAnimation(
      (eventData) => _map.easeTo({
        if (around != null) 'around': around.jsObject,
        if (bearing != null) 'bearing': bearing,
        if (center != null) 'center': center.jsObject,
        if (pitch != null) 'pitch': pitch,
        if (zoom != null) 'zoom': zoom,
        if (duration != null) 'duration': duration.inMilliseconds,
        if (easing != null) 'easing': easing,
      }, eventData),
    );
  }

  @override
  Future<CameraPosition?> queryCameraPosition() async {
    return _readCameraPosition();
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    final (data: geojson, :error) = decodeGeoJson(data);
    if (error != null) throw invalidGeoJson(id, error);
    final source = _editableGeoJsonSource(id);
    if (source == null) return false;
    await source.setData(
      _rememberGeoJson(
        id,
        Map<String, dynamic>.from(geojson! as Map),
        keepIds: _keepFeatureIds(id),
      ),
    );
    return true;
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async {
    final encoded = encodeUrl(url);
    // A url that cannot be one changes nothing, as on Android and iOS.
    if (encoded == null) return false;
    final source = _editableGeoJsonSource(id);
    if (source == null) return false;
    final held = _addedFeaturesByLayer[id];
    _releaseFeatureIds(id);
    await source.setData(encoded.toJS);
    // setGeoJsonFeature cannot change data it does not hold. Data set while
    // the url was handed over came after it, and stays.
    if (identical(_addedFeaturesByLayer[id], held)) {
      _addedFeaturesByLayer.remove(id);
    }
    return true;
  }

  /// The GeoJSON source [id], or null without a style or such a source.
  GeoJsonSource? _editableGeoJsonSource(String id) =>
      _styleReady ? _geoJsonSourceOrNull(id) : null;

  /// The GeoJSON source [sourceId], or null without such a source.
  GeoJsonSource? _geoJsonSourceOrNull(String sourceId) {
    final source = _jsSource(sourceId);
    if (source?.getProperty<JSString?>('type'.toJS)?.toDart != 'geojson') {
      return null;
    }
    return GeoJsonSource.fromJsObject(source! as GeoJsonSourceJsImpl);
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    if (_map.getLayer(layerId) == null) return false;
    try {
      await setFilter(layerId, jsonDecode(filter));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getStyle() async {
    final style = _styleMap();
    if (style == null) return null;
    final sources = style['sources'];
    if (sources is Map) {
      for (final source in sources.values) {
        if (source is Map<String, dynamic>) withoutFeatureIdsInSource(source);
      }
    }
    style['layers'] = withoutFeatureIds(style['layers']);
    return jsonEncode(style);
  }

  @override
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) async {
    // The browser makes the requests of maplibre-gl-js, which offers no
    // per-URL headers.
    throw UnsupportedError(
      'setCustomHeaders is not available on web. Custom headers are supported '
      'on Android and iOS.',
    );
  }

  @override
  Future<Map<String, String>> getCustomHeaders() async {
    throw UnsupportedError(
      'getCustomHeaders is not available on web. Custom headers are supported '
      'on Android and iOS.',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async {
    // Not isStyleLoaded(): it is also false while tiles or a source update
    // load, which would answer nothing for a map that is ready.
    if (!_styleReady) {
      // Style is not loaded yet, return empty list
      print(
        'MapLibreMapController: queryRenderedFeatures, Style not loaded yet, returning empty list',
      );
      return [];
    }

    final options = <String, dynamic>{};
    if (layerIds.isNotEmpty) {
      options['layers'] = layerIds;
    }
    if (filter != null) {
      options['filter'] = withFeatureIds(filter);
    }

    // avoid issues with the js point type
    final geometry = jsify([point.x, point.y]);
    if (geometry == null) return [];

    return _filteredQuery(
      'queryRenderedFeatures',
      filter != null,
      () => _map.queryRenderedFeatures(geometry, options),
    ).map((feature) => _queriedFeature(feature, feature.source)).toList();
  }

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async {
    // Not isStyleLoaded(): it is also false while tiles or a source update
    // load, which would answer nothing for a map that is ready.
    if (!_styleReady) {
      // Style is not loaded yet, return empty list
      print(
        'MapLibreMapController: queryRenderedFeaturesInRect, Style not loaded yet, returning empty list',
      );
      return [];
    }

    final options = <String, dynamic>{};
    if (layerIds.isNotEmpty) {
      options['layers'] = layerIds;
    }
    if (filter != null) {
      // This call takes the filter as a JSON string, where
      // queryRenderedFeatures takes the expression itself. maplibre-gl-js only
      // accepts the expression, so the string has to be decoded here or the
      // filter never reaches the query. Only an expression array filters, and
      // text that is not JSON is an error.
      final Object? decoded;
      try {
        decoded = jsonDecode(filter);
      } on FormatException {
        throw _invalidFilter(_filterNotJson);
      }
      if (decoded is List) options['filter'] = withFeatureIds(decoded);
    }

    final geometry = jsify([
      [rect.left, rect.bottom],
      [rect.right, rect.top],
    ]);
    if (geometry == null) return [];
    return _filteredQuery(
      'queryRenderedFeatures',
      options.containsKey('filter'),
      () => _map.queryRenderedFeatures(geometry, options),
    ).map((feature) => _queriedFeature(feature, feature.source)).toList();
  }

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async {
    // Without a style, an empty list would read as a source without features.
    // Not isStyleLoaded(): it is also false while tiles or a source update
    // load.
    _ensureStyleReady();

    final parameters = <String, dynamic>{};

    if (sourceLayerId != null) {
      parameters['sourceLayer'] = sourceLayerId;
    }

    if (filter != null) {
      parameters['filter'] = withFeatureIds(filter);
    }

    return _filteredQuery(
          'querySourceFeatures',
          filter != null,
          () => _map.querySourceFeatures(sourceId, parameters),
        )
        // maplibre-gl-js leaves `source` unset on these features, so name the
        // source that was queried.
        .map((feature) => _queriedFeature(feature, sourceId))
        .toList();
  }

  /// [feature] as the queries answer it, with the id it has in the data.
  static Map<String, dynamic> _queriedFeature(Feature feature, String source) {
    final properties = feature.properties;
    return <String, dynamic>{
      'type': 'Feature',
      'id': takeFeatureId(feature.id, properties),
      'geometry': <String, dynamic>{
        'type': feature.geometry.type,
        'coordinates': feature.geometry.coordinates,
      },
      'properties': properties,
      'source': source,
    };
  }

  /// Runs [query], the maplibre-gl-js feature query [method], and throws
  /// `INVALID_EXPRESSION` for a filter maplibre-gl-js rejects. It reports such
  /// a filter through an error event, then throws its own error or queries
  /// anyway.
  T _filteredQuery<T>(String method, bool filtered, T Function() query) {
    if (!filtered) return query();
    late T features;
    Object? thrown;
    StackTrace? thrownStack;
    final errors = _mapErrorsDuring(() {
      try {
        features = query();
      } catch (error, stack) {
        thrown = error;
        thrownStack = stack;
      }
    });
    String? reason;
    for (final message in errors) {
      final filterReason = checks.filterReason(message, method);
      if (filterReason == null) {
        // Not about the filter: logged, as maplibre-gl-js does without a
        // listener.
        web.console.error(message.toJS);
      } else {
        reason ??= filterReason;
      }
    }
    if (reason != null) throw _invalidFilter(reason);
    if (thrown case final error?) {
      Error.throwWithStackTrace(error, thrownStack!);
    }
    return features;
  }

  /// Runs [action] and returns the messages of the error events
  /// maplibre-gl-js fired meanwhile. It reports what fails its validation
  /// that way instead of throwing.
  List<String> _mapErrorsDuring(void Function() action) {
    final errors = <String>[];
    final listener =
        ((JSObject event) {
          final message =
              event
                  .getProperty<JSObject?>('error'.toJS)
                  ?.getProperty<JSString?>('message'.toJS)
                  ?.toDart;
          if (message != null) errors.add(message);
        }).toJS;
    final map = _map.jsObject as JSObject;
    map.callMethod<JSAny?>('on'.toJS, 'error'.toJS, listener);
    try {
      action();
    } finally {
      map.callMethod<JSAny?>('off'.toJS, 'error'.toJS, listener);
    }
    return errors;
  }

  /// Why a filter whose text is not JSON cannot be read.
  static const _filterNotJson = 'Not valid JSON.';

  /// The error for a filter maplibre-gl-js rejects or cannot read.
  static PlatformException _invalidFilter(String reason) => PlatformException(
    code: 'INVALID_EXPRESSION',
    message: 'Invalid filter: $reason',
    details: reason,
  );

  /// Checks the source a feature state call addresses, with the errors
  /// Android and iOS answer: `STYLE_NOT_READY`, `SOURCE_NOT_FOUND`,
  /// `UNSUPPORTED_SOURCE_TYPE` for a source that is not GeoJSON or vector, and
  /// `SOURCE_LAYER_REQUIRED` for a vector source without [sourceLayer].
  /// maplibre-gl-js only fires an error event for each of them, which the
  /// caller never sees.
  void _ensureFeatureStateSource(String sourceId, String? sourceLayer) {
    _ensureStyleReady();
    final type = _sourceType(sourceId);
    if (type == null) throw _sourceNotFound(sourceId);
    if (type == 'vector') {
      if (sourceLayer == null) {
        throw checks.featureStateSourceLayerRequired(sourceId);
      }
    } else if (type != 'geojson') {
      throw checks.notFeatureStateSource(sourceId, type);
    }
  }

  /// Resolves the GeoJSON source a cluster-inspection call addresses.
  GeoJsonSource _clusterSource(String sourceId, String methodName) {
    final jsSource = _jsSource(sourceId);
    if (jsSource == null) throw _sourceNotFound(sourceId);
    final source = GeoJsonSource.fromJsObject(
      jsSource as GeoJsonSourceJsImpl,
    );
    if (!source.hasClusterInspection) {
      throw checks.notGeoJsonSource(sourceId, methodName, clustered: true);
    }
    return source;
  }

  /// Runs a cluster query, throwing CLUSTER_NOT_FOUND unless [sourceId]
  /// currently holds the cluster [clusterId] in its loaded tiles.
  ///
  /// Only the JS call runs inside the guard. Decoding happens after this
  /// returns, so a bug there throws on its own rather than being reported as a
  /// clustering mistake.
  Future<T> _clusterQuery<T extends JSAny>(
    String sourceId,
    int clusterId,
    Future<T> Function() call,
  ) async {
    final clusters = _map.querySourceFeatures(sourceId, {
      'filter': [
        '==',
        ['get', 'cluster_id'],
        clusterId,
      ],
    });
    if (clusters.isNotEmpty) {
      try {
        return await call();
      } catch (_) {
        // Rejected: the id went stale between the lookup and the query.
      }
    }
    throw PlatformException(
      code: 'CLUSTER_NOT_FOUND',
      message:
          "Cluster '$clusterId' is not one of the current clusters of source "
          "'$sourceId'. Cluster ids are reassigned as the data or the "
          'viewport changes, so read the id from a freshly queried feature.',
    );
  }

  /// The features of a cluster query, each with the id it has in the data.
  List<Map<String, dynamic>> _clusterFeatures(JSArray<JSObject> features) => [
    for (final feature in features.toDart.map(dartifyMap))
      if (feature['properties'] case final Map? properties
          when feature.containsKey('id') ||
              (properties?.containsKey(featureIdProperty) ?? false))
        feature..['id'] = takeFeatureId(feature['id'], properties)
      else
        feature,
  ];

  @override
  Future<int> getClusterExpansionZoom(String sourceId, int clusterId) async {
    final source = _clusterSource(sourceId, 'getClusterExpansionZoom');
    final zoom = await _clusterQuery(
      sourceId,
      clusterId,
      () => source.getClusterExpansionZoom(clusterId),
    );
    return zoom.toDartDouble.round();
  }

  @override
  Future<List<Map<String, dynamic>>> getClusterChildren(
    String sourceId,
    int clusterId,
  ) async {
    final source = _clusterSource(sourceId, 'getClusterChildren');
    return _clusterFeatures(
      await _clusterQuery(
        sourceId,
        clusterId,
        () => source.getClusterChildren(clusterId),
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getClusterLeaves(
    String sourceId,
    int clusterId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final source = _clusterSource(sourceId, 'getClusterLeaves');
    return _clusterFeatures(
      await _clusterQuery(
        sourceId,
        clusterId,
        () => source.getClusterLeaves(clusterId, limit, offset),
      ),
    );
  }

  @override
  Future invalidateAmbientCache() async {
    print('Offline storage not available in web');
  }

  @override
  Future clearAmbientCache() async {
    print('Offline storage not available in web');
  }

  @override
  Future<LatLng?> requestMyLocationLatLng() async {
    return _myLastLocation;
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    final bounds = _map.getBounds();
    return LatLngBounds(
      southwest: LatLng(
        bounds.getSouthWest().lat as double,
        bounds.getSouthWest().lng as double,
      ),
      northeast: LatLng(
        bounds.getNorthEast().lat as double,
        bounds.getNorthEast().lng as double,
      ),
    );
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
    double? pixelRatio,
  ]) async {
    // Same contract as Android: bytes that are not an image are a
    // PlatformException, not a null-check error. decodeImage answers null for
    // an unknown format and can throw on a truncated one.
    final photo = () {
      try {
        return decodeImage(bytes);
      } catch (_) {
        return null;
      }
    }();
    if (photo == null) {
      throw PlatformException(
        code: 'INVALID_IMAGE',
        message: 'Failed to decode image bytes.',
      );
    }
    // Convert image to RGBA format with proper byte ordering
    final rgbaBytes = photo.convert(numChannels: 4).getBytes();
    final data = Uint8List.fromList(rgbaBytes);

    // An existing name is replaced, as on Android and iOS. Remove and add
    // rather than updateImage, which requires the same size and keeps the old
    // sdf flag.
    if (_map.hasImage(name)) {
      _map.removeImage(name);
    }
    await _map.addImage(
      name,
      {'width': photo.width, 'height': photo.height, 'data': data},
      {'sdf': sdf, 'pixelRatio': pixelRatio ?? 1},
    );
  }

  @override
  Future<void> removeSource(String sourceId) async {
    _ensureStyleReady();
    if (_map.getSource(sourceId) == null) return;
    _map.removeSource(sourceId);
    // maplibre-gl-js keeps a source a layer still uses, as MapLibre Native
    // does, and only reports it in an error event. What is known about the
    // source stays with it.
    if (_map.getSource(sourceId) != null) return;
    _forgetImageUrl(sourceId);
    _addedFeaturesByLayer.remove(sourceId);
  }

  /// Camera position for the streaming paths (e.g. reporting the position after
  /// an option update), which only report it while [_trackCameraPosition] is on.
  CameraPosition? _getCameraPosition() {
    return _trackCameraPosition ? _readCameraPosition() : null;
  }

  /// Reads the current camera position from the map.
  CameraPosition _readCameraPosition() {
    final center = _map.getCenter();
    return CameraPosition(
      bearing: _map.getBearing() as double,
      target: LatLng(center.lat as double, center.lng as double),
      tilt: _map.getPitch() as double,
      zoom: _map.getZoom() as double,
    );
  }

  void _onStyleLoaded(data) {
    final loaded = _map.isStyleLoaded();
    if (!loaded) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _onStyleLoaded(data);
      });
      return;
    }
    _styleReady = true;
    _onMapResize();
    onMapStyleLoadedPlatform(null);
  }

  /// Whether the current style has loaded, as reported to
  /// onStyleLoadedCallback. Unlike `isStyleLoaded()`, it stays true while
  /// sources and tiles load.
  bool _styleReady = false;

  void _onMapResize() {
    Timer(Duration.zero, () {
      final container = _map.getContainer();
      final canvas = _map.getCanvas();
      final widthMismatch = canvas.clientWidth != container.clientWidth;
      final heightMismatch = canvas.clientHeight != container.clientHeight;
      if (widthMismatch || heightMismatch) {
        _map.resize();
      }
    });
  }

  /// Handle map click event
  ///
  /// If the click intersects with any features in interactive layers, trigger
  /// `onFeatureTappedPlatform` with the first feature's info.
  /// Otherwise, trigger `onMapClickPlatform`.
  ///
  /// Both events include the click point and latLng.
  void _onMapClick(Event e) {
    // The click that ends a drag is not a tap, as on Android and iOS.
    if (_featureDrag.takeClickAfterDrag()) return;
    final geometry = jsify([
      [e.point.x, e.point.y],
      [e.point.x, e.point.y],
    ]);
    if (geometry == null) return;
    // Query rendered features in the point box
    final features = _map.queryRenderedFeatures(geometry);

    // Keep only interactive-layer features (preserve order)
    final filtered = features
        .where((f) => _interactiveFeatureLayerIds.contains(f.layerId))
        .toList(growable: false);

    // Prepare common payload for both events (mapClick or featureTapped)
    final payload = <String, dynamic>{
      'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
      'latLng': LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble()),
    };

    if (filtered.isNotEmpty) {
      // Add 'first' feature info to payload
      payload['layerId'] = filtered.first.layerId;
      payload['id'] = plainFeatureId(filtered.first.id);
      onFeatureTappedPlatform(payload);
      // Fire onMapClickPlatform only if featureTapsTriggersMapClick is true
      if (_featureTapsTriggersMapClick) {
        onMapClickPlatform(payload);
      }
    } else {
      // Always fire onMapClickPlatform when no feature is tapped
      onMapClickPlatform(payload);
    }
  }

  void _onMapLongClick(e) {
    onMapLongClickPlatform({
      'point': Point<double>(e.point.x, e.point.y),
      'latLng': LatLng(e.lngLat.lat, e.lngLat.lng),
    });
  }

  void _onCameraMoveStarted(Event e) {
    if (_skipCameraMoveStarted) {
      _skipCameraMoveStarted = false;
      return;
    }
    onCameraMoveStartedPlatform(
      cameraMoveReason(
        e.jsObject as JSObject,
        scrollZooming: _map.scrollZoom.isActive(),
      ),
    );
  }

  // Positions go out only while [_trackCameraPosition] is on, as on Android
  // and iOS.
  void _onCameraMove(_) {
    if (!_trackCameraPosition) return;
    onCameraMovePlatform(_readCameraPosition());
  }

  void _onCameraIdle(_) {
    if (_holdingCameraIdle) {
      _cameraIdleHeld = true;
      return;
    }
    onCameraIdlePlatform(_getCameraPosition());
  }

  void _onMapIdle(_) {
    onMapIdlePlatform(null);
  }

  void _onCameraTrackingChanged(bool isTracking) {
    _trackUserLocation = isTracking;
    if (isTracking) {
      onCameraTrackingChangedPlatform(MyLocationTrackingMode.tracking);
    } else {
      onCameraTrackingChangedPlatform(MyLocationTrackingMode.none);
    }
  }

  void _onCameraTrackingDismissed() {
    onCameraTrackingDismissedPlatform(null);
  }

  void _addGeolocateControl() {
    _removeGeolocateControl();
    _geolocateControl = GeolocateControl(
      GeolocateControlOptions(
        positionOptions: PositionOptions(
          enableHighAccuracy: _enableHighAccuracy,
          maximumAge: _maximumAge > 0 ? _maximumAge : null,
          timeout: _timeout > 0 ? _timeout : null,
        ),
        trackUserLocation: _trackUserLocation,
        showAccuracyCircle: true,
        showUserLocation: true,
      ),
    );
    _geolocateControl!.on('geolocate', (e) {
      final event = GeolocateResultEvent.fromJsObject(
        e as GeolocateResultEventJsImpl,
      );
      final coords = event.coords;
      _myLastLocation = LatLng(
        coords.latitude.toDouble(),
        coords.longitude.toDouble(),
      );
      onUserLocationUpdatedPlatform(
        UserLocation(
          position: LatLng(
            coords.latitude.toDouble(),
            coords.longitude.toDouble(),
          ),
          altitude: coords.altitude?.toDouble(),
          bearing: coords.heading?.toDouble(),
          speed: coords.speed?.toDouble(),
          horizontalAccuracy: coords.accuracy?.toDouble(),
          verticalAccuracy: coords.altitudeAccuracy?.toDouble(),
          heading: null,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            event.timestamp.toInt(),
          ),
        ),
      );
    });
    _geolocateControl!.on('trackuserlocationstart', (_) {
      _onCameraTrackingChanged(true);
    });
    _geolocateControl!.on('trackuserlocationend', (_) {
      _onCameraTrackingChanged(false);
      _onCameraTrackingDismissed();
    });
    _map.addControl(_geolocateControl, 'bottom-right');
  }

  /// Triggers the geolocate control, retrying if the control's internal
  /// async setup hasn't completed yet (e.g. geolocation permission check).
  void _triggerGeolocateControl([int retries = 5]) {
    if (_geolocateControl == null) return;
    final success = _geolocateControl!.trigger();
    if (!success && retries > 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _triggerGeolocateControl(retries - 1);
      });
    }
  }

  void _removeGeolocateControl() {
    if (_geolocateControl != null) {
      _map.removeControl(_geolocateControl);
      _geolocateControl = null;
    }
  }

  void _updateNavigationControl({
    bool? compassEnabled,
    CompassViewPosition? position,
  }) {
    bool? prevShowCompass;
    if (_navigationControl != null) {
      prevShowCompass = _navigationControl!.options.showCompass;
    }
    final prevPosition = _navigationControlPosition;

    final positionString = switch (position) {
      CompassViewPosition.topRight => 'top-right',
      CompassViewPosition.topLeft => 'top-left',
      CompassViewPosition.bottomRight => 'bottom-right',
      CompassViewPosition.bottomLeft => 'bottom-left',
      _ => null,
    };

    final newShowCompass = compassEnabled ?? prevShowCompass ?? false;
    final newPosition = positionString ?? prevPosition;

    _removeNavigationControl();
    _navigationControl = NavigationControl(
      NavigationControlOptions(
        showCompass: newShowCompass,
        showZoom: false,
        visualizePitch: false,
      ),
    );

    if (newPosition == null) {
      _map.addControl(_navigationControl);
    } else {
      _map.addControl(_navigationControl, newPosition);
      _navigationControlPosition = newPosition;
    }
  }

  void _removeNavigationControl() {
    if (_navigationControl != null) {
      _map.removeControl(_navigationControl);
      _navigationControl = null;
    }
  }

  /// Puts the attribution control at [_attributionButtonPosition], or removes
  /// it while [_attributionEnabled] is false.
  void _updateAttributionButton() {
    _removeAttributionButton();
    if (!_attributionEnabled) return;

    String? positionString;
    switch (_attributionButtonPosition) {
      case AttributionButtonPosition.topRight:
        positionString = 'top-right';
      case AttributionButtonPosition.topLeft:
        positionString = 'top-left';
      case AttributionButtonPosition.bottomRight:
        positionString = 'bottom-right';
      case AttributionButtonPosition.bottomLeft:
        positionString = 'bottom-left';
    }

    _attributionControl = AttributionControl(AttributionControlOptions());
    _map.addControl(_attributionControl, positionString);
  }

  void _removeAttributionButton() {
    if (_attributionControl != null) {
      _map.removeControl(_attributionControl);
      _attributionControl = null;
    }
  }

  /*
   *  MapLibreMapOptionsSink
   */
  @override
  void setAttributionButtonMargins(int x, int y) {
    print('setAttributionButtonMargins not available in web');
  }

  @override
  void setScaleControlEnabled(bool enabled) {
    if (enabled) {
      _addScaleControl();
    } else {
      _removeScaleControl();
    }
  }

  @override
  void setScaleControlPosition(ScaleControlPosition position) {
    final positionString = switch (position) {
      ScaleControlPosition.topLeft => 'top-left',
      ScaleControlPosition.topRight => 'top-right',
      ScaleControlPosition.bottomLeft => 'bottom-left',
      ScaleControlPosition.bottomRight => 'bottom-right',
    };
    // Only re-add if position changed
    if (_scaleControl != null && _scaleControlPosition != positionString) {
      _addScaleControl(position: position);
    }
  }

  @override
  void setScaleControlUnit(ScaleControlUnit unit) {
    if (_scaleControl != null) {
      final unitString = switch (unit) {
        ScaleControlUnit.metric => 'metric',
        ScaleControlUnit.imperial => 'imperial',
        ScaleControlUnit.nautical => 'nautical',
      };
      _scaleControl!.setUnit(unitString);
    }
  }

  @override
  void setFeatureTapsTriggersMapClick(bool triggers) {
    _featureTapsTriggersMapClick = triggers;
  }

  /// The symbol fade the map had before placement transitions were turned
  /// off, so turning them on again restores it. Null while they are on.
  ///
  /// maplibre-gl-js has no switch of its own: a fade of 0 is the same thing,
  /// since placement then runs on every frame and symbols change at once,
  /// as with placement transitions off on Android and iOS. The fade belongs
  /// to the map, not the style, so it survives style changes.
  num? _placementFadeBeforeOff;

  @override
  void setSymbolPlacementTransitionsEnabled(bool enabled) {
    if (enabled) {
      final previous = _placementFadeBeforeOff;
      if (previous == null) return;
      _placementFadeBeforeOff = null;
      _map.placementFadeDuration = previous;
    } else {
      if (_placementFadeBeforeOff != null) return;
      _placementFadeBeforeOff = _map.placementFadeDuration;
      _map.placementFadeDuration = 0;
    }
    // Draws what was placed while the fade was off, as on Android and iOS.
    _map.triggerRepaint();
  }

  void _addScaleControl({ScaleControlPosition? position}) {
    _removeScaleControl();

    final positionString = switch (position ??
        ScaleControlPosition.bottomLeft) {
      ScaleControlPosition.topLeft => 'top-left',
      ScaleControlPosition.topRight => 'top-right',
      ScaleControlPosition.bottomLeft => 'bottom-left',
      ScaleControlPosition.bottomRight => 'bottom-right',
    };

    _scaleControl = ScaleControl(ScaleControlOptions(maxWidth: 80));
    _scaleControlPosition = positionString;
    _map.addControl(_scaleControl, positionString);
  }

  void _removeScaleControl() {
    if (_scaleControl != null) {
      _map.removeControl(_scaleControl);
      _scaleControl = null;
      _scaleControlPosition = null;
    }
  }

  @override
  void setCameraTargetBounds(LatLngBounds? bounds) {
    if (bounds == null) {
      _map.setMaxBounds(null);
    } else {
      _map.setMaxBounds(
        LngLatBounds(
          LngLat(bounds.southwest.longitude, bounds.southwest.latitude),
          LngLat(bounds.northeast.longitude, bounds.northeast.latitude),
        ),
      );
    }
  }

  @override
  void setCompassEnabled(bool compassEnabled) {
    _updateNavigationControl(compassEnabled: compassEnabled);
  }

  @override
  void setCompassAlignment(CompassViewPosition position) {
    _updateNavigationControl(position: position);
  }

  @override
  void setAttributionEnabled(bool enabled) {
    // Sent with every map creation, before the position. The control is put
    // by the position, or by the creation code when the options carry none.
    if (enabled == _attributionEnabled) return;
    _attributionEnabled = enabled;
    _updateAttributionButton();
  }

  @override
  void setAttributionButtonAlignment(AttributionButtonPosition position) {
    _attributionButtonPosition = position;
    _updateAttributionButton();
  }

  @override
  void setCompassViewMargins(int x, int y) {
    print('setCompassViewMargins not available in web');
  }

  @override
  void setLogoViewAlignment(LogoViewPosition position) {
    print('setLogoViewAlignment not available in web');
  }

  @override
  void setLogoViewMargins(int x, int y) {
    print('setLogoViewMargins not available in web');
  }

  @override
  void setMinMaxZoomPreference(num? min, num? max) {
    // FIX: why is called indefinitely? (map_ui page)
    _map.setMinZoom(min);
    _map.setMaxZoom(max);
  }

  @override
  void setMyLocationEnabled(bool myLocationEnabled) {
    final wasEnabled = _myLocationEnabled;
    _myLocationEnabled = myLocationEnabled;
    if (myLocationEnabled) {
      if (_manualLocationSource) {
        // Never use the browser geolocation control in manual mode. Enabling
        // replays the last fix, also one pushed while disabled, so the puck
        // shows up there and reports it, as iOS does; without one it is built
        // on the next fix pushed via setManualLocation.
        _removeGeolocateControl();
        _showManualPuck();
        if (!wasEnabled) {
          if (_lastManualFix case final fix?) _reportManualFix(fix);
        }
      } else {
        _addGeolocateControl();
      }
    } else {
      _removeGeolocateControl();
      _removeManualPuck();
    }
  }

  @override
  void setMyLocationStyle(Map<String, dynamic> style) {
    // Plain CSS on the map container, so it styles the puck whichever source
    // draws it, and whether it exists yet or not.
    (_locationPuckStyler ??= LocationPuckStyler(_mapElement)).apply(style);
  }

  @override
  void setMyLocationRenderMode(int myLocationRenderMode) {
    print('myLocationRenderMode not available in web');
  }

  @override
  void setMyLocationTrackingMode(int myLocationTrackingMode) {
    final shouldTrack = myLocationTrackingMode != 0;
    // Always remember the requested mode, even if the manual source hasn't been
    // resolved yet. `Convert` calls this before `setLocationSource`, so at map
    // creation the manual flag is still false here; `setLocationSource('manual')`
    // then applies the stored mode to the puck. Without this the initial
    // tracking mode was lost until the user toggled it manually.
    _manualTrackingMode = myLocationTrackingMode;

    if (_manualLocationSource) {
      _manualPuck?.setTrackingMode(myLocationTrackingMode);
      return;
    }

    if (_geolocateControl == null) {
      //myLocationEnabled is false, ignore myLocationTrackingMode
      return;
    }
    if (shouldTrack != _trackUserLocation) {
      _trackUserLocation = shouldTrack;
      _addGeolocateControl();
      _triggerGeolocateControl();
    }
  }

  @override
  void setLocationEngineProperties({
    required bool enableHighAccuracy,
    required int maximumAge,
    required int timeout,
  }) {
    final changed =
        enableHighAccuracy != _enableHighAccuracy ||
        maximumAge != _maximumAge ||
        timeout != _timeout;
    _enableHighAccuracy = enableHighAccuracy;
    _maximumAge = maximumAge;
    _timeout = timeout;
    if (changed && _geolocateControl != null) {
      _addGeolocateControl();
      _triggerGeolocateControl();
    }
  }

  @override
  void setLocationSource(String token) {
    // Web resolves the token here. In 'manual' mode we render our own puck
    // (dot + accuracy circle + bearing arrow) and never use the browser
    // GeolocateControl; in 'platform' mode we keep the default control.
    // Applied at activation; either call order (source vs. enabled) is fine
    // because both consult these flags.
    _manualLocationSource = token == 'manual';
    if (_manualLocationSource) {
      _removeGeolocateControl();
      // The puck builds its markers lazily on the first fix; ensuring it here
      // (when enabled) seeds the tracking mode that `Convert` recorded via
      // setMyLocationTrackingMode (called before this).
      if (_myLocationEnabled) {
        _ensureManualPuck().setTrackingMode(_manualTrackingMode);
      }
    } else {
      _removeManualPuck();
      if (_myLocationEnabled) _addGeolocateControl();
    }
  }

  /// Sets the map style.
  ///
  /// The [styleString] parameter can be one of the following:
  /// - A JSON string representing a MapLibre style object.
  /// - A URL (http/https) pointing to a MapLibre style JSON document.
  /// - An absolute file path to a MapLibre style JSON file.
  /// - An asset path (prefixed with 'assets/') to a style JSON included in the app bundle.
  ///
  /// The style must conform to the MapLibre Style Specification:
  /// https://maplibre.org/projects/maplibre-gl-js/style-spec/
  ///
  /// Example usage:
  /// ```dart
  /// await controller.setStyle('https://demotiles.maplibre.org/style.json');
  /// await controller.setStyle('{"version":8,"sources":{...},"layers":[...]}');
  /// await controller.setStyle('/absolute/path/to/style.json');
  /// await controller.setStyle('assets/styles/my_style.json');
  /// ```
  @override
  Future<void> setStyle(dynamic styleObject) async {
    _styleReady = false;
    _forgetImageUrls();
    _addedFeaturesByLayer.clear();
    //remove old mouseenter callbacks to avoid multicalling
    _interactiveFeatureLayerIds.forEach(_detachLayerInteraction);
    _interactiveFeatureLayerIds.clear();
    // The new style drops every layer, hovered features included.
    _hoveredFeatureIdsByLayer.keys.toList().forEach(_dropLayerHover);

    final sanitizedStyle = await _sanitizeStyleObject(styleObject);
    _map.setStyle(sanitizedStyle, {'diff': false});
  }

  /// Sanitizes the style object to ensure it is in the correct format.
  ///
  /// - JSON strings are parsed via native JSON.parse to avoid Dart metadata
  ///   leaking into web workers.
  /// - Asset paths (starting with `assets/`) are loaded via [rootBundle] and
  ///   returned as parsed JS objects, because static asset files are not
  ///   directly addressable as HTTP resources in all Flutter web deployment
  ///   configurations (e.g. GitHub Pages with a non-root base href).
  Future<dynamic> _sanitizeStyleObject(dynamic styleObject) async {
    if (styleObject is String) {
      if (styleObject.startsWith('{') || styleObject.startsWith('[')) {
        return jsonParse(styleObject);
      }
      if (styleObject.startsWith('assets/')) {
        final jsonString = await rootBundle.loadString(styleObject);
        return jsonParse(jsonString);
      }
    }
    return styleObject;
  }

  @override
  void setTrackCameraPosition(bool trackCameraPosition) {
    _trackCameraPosition = trackCameraPosition;
  }

  @override
  Future<LatLng> toLatLng(Point<num> screenLocation) async {
    if (!checks.isFinite(screenLocation.x, screenLocation.y)) {
      throw checks.invalidArgument(checks.nonFiniteScreenPoint);
    }
    final lngLat = _map.unproject(
      geo_point.Point(screenLocation.x, screenLocation.y),
    );
    return LatLng(lngLat.lat as double, lngLat.lng as double);
  }

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    _checkLatLngs([latLng]);
    final screenPosition = _map.project(
      LngLat(latLng.longitude, latLng.latitude),
    );
    final point = Point(screenPosition.x.round(), screenPosition.y.round());

    return point;
  }

  @override
  Future<List<Point<num>>> toScreenLocationBatch(
    Iterable<LatLng> latLngs,
  ) async {
    _checkLatLngs(latLngs);
    return latLngs
        .map((latLng) {
          final screenPosition = _map.project(
            LngLat(latLng.longitude, latLng.latitude),
          );
          return Point(screenPosition.x.round(), screenPosition.y.round());
        })
        .toList(growable: false);
  }

  /// Throws `INVALID_ARGUMENT`, as Android and iOS do, for a latitude or
  /// longitude in [latLngs] that is NaN or infinite.
  static void _checkLatLngs(Iterable<LatLng> latLngs) {
    for (final latLng in latLngs) {
      if (!checks.isFinite(latLng.latitude, latLng.longitude)) {
        throw checks.invalidArgument(checks.nonFiniteCoordinates);
      }
    }
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    //https://wiki.openstreetmap.org/wiki/Zoom_levels
    const circumference = 40075017.686;
    final zoom = _map.getZoom();
    return circumference * cos(latitude * (pi / 180)) / pow(2, zoom + 9);
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    _ensureStyleReady();
    _ensureLayerExists(imageLayerId);
    // A layer added again under this id attaches its own listeners, so these
    // must go with it or each hover and drag callback runs once per add.
    if (_interactiveFeatureLayerIds.remove(imageLayerId)) {
      _detachLayerInteraction(imageLayerId);
      _dropLayerHover(imageLayerId);
    }
    _map.removeLayer(imageLayerId);
  }

  /// Throws `STYLE_NOT_READY` until the style has loaded, in place of the
  /// errors maplibre-gl-js throws then.
  void _ensureStyleReady() {
    if (!_styleReady) {
      throw PlatformException(
        code: 'STYLE_NOT_READY',
        message:
            'Style is null or not fully loaded. Has onStyleLoaded() already '
            'been invoked?',
      );
    }
  }

  /// Throws `SOURCE_NOT_FOUND` for a source the style does not hold.
  /// maplibre-gl-js would skip a layer of it and only fire an error event.
  void _ensureSourceExists(String sourceId) {
    if (_map.getSource(sourceId) == null) throw _sourceNotFound(sourceId);
  }

  static PlatformException _sourceNotFound(String sourceId) =>
      PlatformException(
        code: 'SOURCE_NOT_FOUND',
        message: "Source '$sourceId' does not exist in the current style.",
      );

  /// The type of the source [sourceId], such as `geojson` or `image`, or
  /// null without such a source. [MapLibreMap.getSource] wraps every source
  /// in a GeoJsonSource, so the type is read off the source itself.
  String? _sourceType(String sourceId) =>
      _jsSource(sourceId)?.getProperty<JSString?>('type'.toJS)?.toDart;

  /// The source [sourceId] as maplibre-gl-js holds it, or null.
  JSObject? _jsSource(String sourceId) => (_map.jsObject as JSObject)
      .callMethod<JSObject?>('getSource'.toJS, sourceId.toJS);

  /// [belowLayerId] when the style holds that layer, and null otherwise, so a
  /// layer added below a missing one goes on top. maplibre-gl-js would not add
  /// it at all.
  String? _existingLayerId(String? belowLayerId) =>
      belowLayerId != null && _map.getLayer(belowLayerId) != null
          ? belowLayerId
          : null;

  /// Throws `LAYER_NOT_FOUND_ERROR`, as Android and iOS do, for a missing
  /// layer. maplibre-gl-js only fires an error event, which callers never see.
  void _ensureLayerExists(String layerId) {
    if (_map.getLayer(layerId) == null) {
      throw PlatformException(
        code: 'LAYER_NOT_FOUND_ERROR',
        message: 'Layer not found',
        details: 'Layer with id $layerId not found.',
      );
    }
  }

  /// Throws `LAYER_ALREADY_EXISTS`, as Android and iOS do, for a layer id
  /// already in use.
  void _ensureNewLayerId(String layerId) {
    if (_map.getLayer(layerId) != null) {
      throw PlatformException(
        code: 'LAYER_ALREADY_EXISTS',
        message: 'Layer already exists',
        details: 'Layer with id $layerId already exists.',
      );
    }
  }

  /// Throws `SOURCE_ALREADY_EXISTS`, as Android and iOS do, for a source id
  /// already in use, instead of the raw JS error maplibre-gl-js throws.
  void _ensureNewSourceId(String sourceId) {
    if (_map.getSource(sourceId) != null) {
      throw PlatformException(
        code: 'SOURCE_ALREADY_EXISTS',
        message: 'Source already exists',
        details: 'Source with id $sourceId already exists.',
      );
    }
  }

  @override
  Future<void> moveLayer(String layerId, {String? belowLayerId}) async {
    // maplibre-gl-js only fires an error event for a missing layer, so check
    // both first and throw the same error as Android and iOS.
    _ensureLayerExists(layerId);
    if (belowLayerId != null) _ensureLayerExists(belowLayerId);
    if (belowLayerId == layerId) return;
    _map.moveLayer(layerId, belowLayerId);
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    _checkFilterable(layerId);
    // GL JS reports an invalid filter through an error event instead of
    // throwing, so listen for it while the filter is set.
    final errors = _mapErrorsDuring(
      () => _map.setFilter(layerId, withFeatureIds(filter)),
    );
    if (errors.isNotEmpty) {
      final message = errors.first;
      throw _invalidFilter(
        checks.filterReason(message, 'layers.$layerId') ?? message,
      );
    }
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    // maplibre-gl-js would only report bad data later, in an error event.
    final reason = geoJsonError(geojson);
    if (reason != null) throw invalidGeoJson(sourceId, reason);
    _ensureStyleReady();
    // Before the cache write below, so a rejected add keeps the original's data.
    _ensureNewSourceId(sourceId);
    final (data, features) = _geoJsonData(geojson);
    _addedFeaturesByLayer[sourceId] = features;
    _addGeoJsonSource(
      sourceId,
      jsifyMap({
        'type': 'geojson',
        if (promoteId != null) 'promoteId': promoteId,
      }),
      data,
      features,
    );
  }

  /// Adds the GeoJSON source [sourceId] with [options] and [data], whose
  /// features are [features], and makes it keep their ids when it can.
  /// maplibre-gl-js hands the data to its worker asynchronously, so ids copied
  /// right after the add still go with it.
  void _addGeoJsonSource(
    String sourceId,
    JSObject options,
    JSObject data,
    List<_SourceFeature> features,
  ) {
    options.setProperty('data'.toJS, data);
    (_map.jsObject as JSObject).callMethod<JSAny?>(
      'addSource'.toJS,
      sourceId.toJS,
      options,
    );
    // A new source has no layer to rewrite yet.
    final source = _jsSource(sourceId);
    if (source != null && promoteFeatureIds(source, promote: true)) {
      _copyFeatureIds(features);
    }
  }

  /// [geojson] as a JS object, keeping its features for
  /// [setFeatureForGeoJsonSource]. A lone Feature counts as a collection of
  /// one; a geometry has no feature to replace. An object in it goes in as
  /// what its `toJson()` returns, as on Android and iOS. With [keepIds], each
  /// feature also carries its id in [featureIdProperty].
  JSObject _rememberGeoJson(
    String sourceId,
    Map<String, dynamic> geojson, {
    required bool keepIds,
  }) {
    final (data, features) = _geoJsonData(geojson);
    if (keepIds) _copyFeatureIds(features);
    _addedFeaturesByLayer[sourceId] = features;
    return data;
  }

  /// [geojson] as a JS object, and its features. See [_rememberGeoJson].
  static (JSObject, List<_SourceFeature>) _geoJsonData(
    Map<dynamic, dynamic> geojson,
  ) {
    final data = jsifyJson(geojson)! as JSObject;
    final List<_SourceFeature> features;
    switch (jsonValueOf(geojson['type'])) {
      case 'FeatureCollection':
        final jsFeatures =
            data.getProperty<JSArray<JSAny?>>('features'.toJS).toDart;
        final dartFeatures = jsonValueOf(geojson['features'])! as List;
        features = [
          for (var i = 0; i < dartFeatures.length; i++)
            (
              id: _featureIdKey(_jsonId(dartFeatures[i])),
              feature: jsFeatures[i],
            ),
        ];
      case 'Feature':
        features = [(id: _featureIdKey(_jsonId(geojson)), feature: data)];
      default:
        features = const [];
    }
    return (data, features);
  }

  /// Copies the id of each of [features] that has one into its
  /// [featureIdProperty].
  static void _copyFeatureIds(List<_SourceFeature> features) {
    for (final (:id, :feature) in features) {
      if (id != null) copyFeatureId(feature! as JSObject);
    }
  }

  /// Makes the GeoJSON source [sourceId] take its feature ids from
  /// [featureIdProperty], for data the plugin sets, and answers whether it
  /// does: see [promoteFeatureIds]. When it starts to, the layers of the
  /// style on it read those ids with `['id']` too.
  bool _keepFeatureIds(String sourceId) {
    final source = _jsSource(sourceId);
    if (source == null) return false;
    final before = promotesFeatureIds(source);
    if (!promoteFeatureIds(source, promote: true)) return false;
    if (!before) _withFeatureIdsInLayersOf(sourceId);
    return true;
  }

  /// Makes the GeoJSON source [sourceId] take the ids maplibre-gl-js reads,
  /// for data loaded from a URL, which has no [featureIdProperty]. A source
  /// with a `promoteId` of its own keeps it. The layers on it need no change:
  /// `['id']` falls back to those ids.
  void _releaseFeatureIds(String sourceId) {
    final source = _jsSource(sourceId);
    if (source != null) promoteFeatureIds(source, promote: false);
  }

  /// Makes `['id']` in the filter, paint and layout of each layer on the
  /// source [sourceId] read the id in the data, as it does in the layers the
  /// plugin adds. The layers declared in the style still hold `['id']` as
  /// written.
  void _withFeatureIdsInLayersOf(String sourceId) {
    final layers = _map.getStyleObject()?.getProperty<JSAny?>('layers'.toJS);
    if (!layers.isA<JSArray>()) return;
    final map = _map.jsObject as JSObject;
    for (final layer in (layers! as JSArray<JSAny?>).toDart) {
      if (!layer.isA<JSObject>()) continue;
      final spec = layer! as JSObject;
      if (spec.getProperty<JSAny?>('source'.toJS).dartify() != sourceId) {
        continue;
      }
      final layerId = spec.getProperty<JSAny?>('id'.toJS).dartify();
      if (layerId is! String) continue;
      final filter = dartify(spec.getProperty<JSAny?>('filter'.toJS));
      final rewritten = withFeatureIds(filter);
      if (!identical(rewritten, filter)) _map.setFilter(layerId, rewritten);
      for (final (group, setter) in [
        ('paint', 'setPaintProperty'),
        ('layout', 'setLayoutProperty'),
      ]) {
        final properties = dartify(spec.getProperty<JSAny?>(group.toJS));
        if (properties is! Map) continue;
        for (final MapEntry(:key, :value) in properties.entries) {
          final rewritten = withFeatureIds(value);
          if (identical(rewritten, value)) continue;
          map.callMethod<JSAny?>(
            setter.toJS,
            layerId.toJS,
            (key as String).toJS,
            jsify(rewritten),
          );
        }
      }
    }
  }

  /// The id of [feature], a Feature the GeoJSON check accepted, as
  /// `jsonEncode` writes it.
  static Object? _jsonId(Object? feature) =>
      jsonValueOf((jsonValueOf(feature)! as Map)['id']);

  /// A feature id as text, so 2, 2.0 and "2" match, as on Android and iOS.
  static String? _featureIdKey(Object? id) {
    if (id is num && id.isFinite && id == id.roundToDouble()) {
      return id.toInt().toString();
    }
    return id?.toString();
  }

  /// A FeatureCollection of [features], as maplibre-gl-js takes it.
  static JSObject _featureCollection(List<_SourceFeature> features) {
    final collection = JSObject();
    collection.setProperty('type'.toJS, 'FeatureCollection'.toJS);
    collection.setProperty(
      'features'.toJS,
      [for (final feature in features) feature.feature].toJS,
    );
    return collection;
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    final reason = geoJsonError(geojson);
    if (reason != null) throw invalidGeoJson(sourceId, reason);
    final source = _geoJsonSource(sourceId, 'setGeoJsonSource');
    await source.setData(
      _rememberGeoJson(
        sourceId,
        geojson,
        keepIds: _keepFeatureIds(sourceId),
      ),
    );
  }

  /// The GeoJSON source [sourceId], for the Dart method [methodName]. Throws
  /// `STYLE_NOT_READY` without a style, `SOURCE_NOT_FOUND` without the source
  /// and `UNSUPPORTED_SOURCE_TYPE` for a source of another type.
  GeoJsonSource _geoJsonSource(String sourceId, String methodName) {
    _ensureStyleReady();
    if (_jsSource(sourceId) == null) throw _sourceNotFound(sourceId);
    return _geoJsonSourceOrNull(sourceId) ??
        (throw checks.notGeoJsonSource(sourceId, methodName));
  }

  @override
  Future setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {
    // maplibre-gl-js takes any padding and clamps the latitudes, where
    // Android and iOS fail.
    if (!checks.isFinite(north, east) || !checks.isFinite(south, west)) {
      throw checks.invalidArgument(checks.nonFiniteCoordinates);
    }
    if (north.abs() > 90 || south.abs() > 90) {
      throw checks.invalidArgument(checks.latitudeOutOfRange);
    }
    if (padding < -0x80000000 || padding > 0x7FFFFFFF) {
      throw checks.invalidArgument(checks.paddingOutOfRange(padding));
    }
    _cancelCameraAnimation();
    _map.fitBounds(LngLatBounds(LngLat(west, south), LngLat(east, north)), {
      'padding': padding,
    });
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
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "fill-extrusion",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
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
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "circle",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
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
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "fill",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
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
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "line",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    _ensureStyleReady();
    _ensureLayerExists(layerId);
    final layerType = _layerType(layerId);
    final map = _map.jsObject as JSObject;
    // maplibre-gl-js validates one property at a time, so the ones set before
    // a rejected one are put back: a failed call changes nothing.
    final applied = <({String setter, String name, JSAny? previous})>[];
    for (final name in properties.keys.toList()..sort()) {
      if (layerType != null && !checks.isPropertyOf(layerType, name)) continue;
      final value = properties[name];
      final layout = isLayoutProperty(name);
      final setter = layout ? 'setLayoutProperty' : 'setPaintProperty';
      final previous = map.callMethod<JSAny?>(
        (layout ? 'getLayoutProperty' : 'getPaintProperty').toJS,
        layerId.toJS,
        name.toJS,
      );
      var reason = checks.hexColorError(name, value);
      // A hex color fails with the reason Android and iOS give.
      if (reason == null) {
        try {
          final errors = _mapErrorsDuring(
            () => map.callMethod<JSAny?>(
              setter.toJS,
              layerId.toJS,
              name.toJS,
              jsify(withFeatureIds(value)),
            ),
          );
          for (final message in errors) {
            final error = checks.propertyError(message);
            if (error == null || checks.isUnknownProperty(error.reason)) {
              web.console.warn(message.toJS);
            } else {
              reason ??= error.reason;
            }
          }
        } catch (e) {
          // Resetting fails only for a property maplibre-gl-js does not know.
          if (value == null) {
            web.console.warn(
              'Cannot reset "$name" of layer "$layerId": $e'.toJS,
            );
            continue;
          }
          reason = e.toString();
        }
      }
      if (reason != null) {
        for (final set in applied.reversed) {
          map.callMethod<JSAny?>(
            set.setter.toJS,
            layerId.toJS,
            set.name.toJS,
            set.previous,
          );
        }
        throw _invalidProperty(layerId, name, value, reason);
      }
      applied.add((setter: setter, name: name, previous: previous));
    }
  }

  /// The type of the layer [layerId], such as `circle`, or null.
  String? _layerType(String layerId) {
    final layer = _map.getLayer(layerId);
    if (layer == null) return null;
    return (layer as JSObject).getProperty<JSString?>('type'.toJS)?.toDart;
  }

  /// The error for a value of [property] maplibre-gl-js rejected, also logged
  /// as a warning.
  static PlatformException _invalidProperty(
    String layerId,
    String property,
    Object? value,
    String reason,
  ) {
    final error = checks.invalidProperty(layerId, property, value, reason);
    web.console.warn(error.message!.toJS);
    return error;
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
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "symbol",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
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
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "hillshade",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  @override
  Future<void> addColorReliefLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "color-relief",
      belowLayerId: belowLayerId,
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  @override
  Future<void> addBackgroundLayer(
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
  }) async {
    _ensureStyleReady();
    _ensureNewLayerId(layerId);
    _addValidatedLayer(
      layerId,
      'background',
      properties,
      belowLayerId: belowLayerId,
      minzoom: minzoom,
      maxzoom: maxzoom,
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
    dynamic filter,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      "heatmap",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: false,
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
    await _addLayer(
      sourceId,
      layerId,
      properties,
      "raster",
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  /// Replaces the map this controller drives with [map], whose style has
  /// loaded when [styleReady] is true.
  ///
  /// For tests of the calls that do nothing but hand a payload to
  /// maplibre-gl-js, which can then be driven against a stand-in for it.
  @visibleForTesting
  void debugSetMap(MapLibreMap map, {bool styleReady = false}) {
    _map = map;
    _styleReady = styleReady;
  }

  @override
  Future<void> setSky(SkyProperties sky) async {
    _map.setSky(sky.toJson());
  }

  @override
  Future<void> setTerrain(TerrainProperties? terrain) async {
    _map.setTerrain(terrain?.toJson());
  }

  @override
  Future<void> setProjection(Object type) async {
    _map.setProjection(<String, dynamic>{'type': type});
  }

  @override
  Future<void> setLight(LightProperties light) async {
    _map.setLight(light.toJson());
  }

  @override
  Future<void> setGlobalStateProperty(String name, Object? value) async {
    _map.setGlobalStateProperty(name, value);
  }

  Future<void> _addLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties,
    String layerType, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    // Checked first: a second add would attach the hover listeners to the
    // existing layer again, and maplibre-gl-js reports a missing source only
    // through an error event.
    _ensureStyleReady();
    _ensureNewLayerId(layerId);
    _ensureSourceExists(sourceId);
    final sourceType = _sourceType(sourceId);
    if (sourceType != null && !checks.canDraw(layerType, sourceType)) {
      throw checks.incompatibleSource(layerId, layerType, sourceId, sourceType);
    }
    if (sourceType == 'vector' &&
        (sourceLayer == null || sourceLayer.isEmpty)) {
      throw checks.sourceLayerRequired(layerId, sourceId);
    }
    _addValidatedLayer(
      layerId,
      layerType,
      properties,
      belowLayerId: belowLayerId,
      source: <String, dynamic>{
        'source': sourceId,
        if (sourceLayer != null) 'source-layer': sourceLayer,
      },
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
    );

    if (enableInteraction) {
      _interactiveFeatureLayerIds.add(layerId);
      _map.on('mouseenter', layerId, _handleLayerMouseMove);
      _map.on('mousemove', layerId, _handleLayerMouseMove);
      _map.on('mouseleave', layerId, _handleLayerMouseMove);
      if (_dragEnabled) {
        _map.on('mousedown', layerId, _onMouseDown);
        _map.on('touchstart', layerId, _onTouchStart);
      }
    }
  }

  /// Adds the layer [layerId] of [layerType] with [properties] and the
  /// [source] entries. maplibre-gl-js reports an invalid filter or property
  /// only through an error event; this throws it instead, the filter first,
  /// then the property whose name comes first, a hex color MapLibre Native
  /// cannot read included. A property maplibre-gl-js does not know is
  /// dropped. A layer maplibre-gl-js did not add for any other reason fails
  /// with `INVALID_LAYER`.
  void _addValidatedLayer(
    String layerId,
    String layerType,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    Map<String, dynamic> source = const {},
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) {
    // maplibre-gl-js would not add the layer, and MapLibre Native would take
    // any zoom.
    if (!checks.isZoomInRange(minzoom, maxzoom)) {
      throw checks.zoomOutOfRange(layerId);
    }
    final colorErrors = <String, String>{
      for (final MapEntry(:key, :value) in properties.entries)
        if (checks.hexColorError(key, value) case final reason?) key: reason,
    };
    final before = _existingLayerId(belowLayerId);
    filter = withFeatureIds(filter);
    var kept = withFeatureIds(properties)! as Map<String, dynamic>;
    // At most twice: the second time without the properties it did not know.
    for (var attempt = 0; ; attempt++) {
      final layer = <String, dynamic>{
        'id': layerId,
        'type': layerType,
        ...source,
        'layout': {
          for (final entry in kept.entries)
            if (isLayoutProperty(entry.key)) entry.key: entry.value,
        },
        'paint': {
          for (final entry in kept.entries)
            if (!isLayoutProperty(entry.key)) entry.key: entry.value,
        },
        if (minzoom != null) 'minzoom': minzoom,
        if (maxzoom != null) 'maxzoom': maxzoom,
        if (filter != null) 'filter': filter,
      };
      final errors = _mapErrorsDuring(() => _map.addLayer(layer, before));
      String? filterReason;
      checks.PropertyError? propertyError;
      final unknown = <String>{};
      final others = <String>[];
      for (final message in errors) {
        final reason = checks.filterReason(message, 'layers.$layerId');
        if (reason != null) {
          filterReason ??= reason;
          continue;
        }
        final error = checks.propertyError(message);
        if (error == null) {
          others.add(message);
        } else if (checks.isUnknownProperty(error.reason)) {
          web.console.warn(message.toJS);
          unknown.add(error.property);
        } else if (propertyError == null ||
            error.property.compareTo(propertyError.property) < 0) {
          propertyError = error;
        }
      }
      if (filterReason != null) throw _invalidFilter(filterReason);
      var rejected = propertyError;
      for (final MapEntry(key: property, value: reason)
          in colorErrors.entries) {
        if (rejected == null || property.compareTo(rejected.property) <= 0) {
          rejected = (property: property, reason: reason);
        }
      }
      if (rejected case final error?) {
        // A failed add changes nothing, whatever maplibre-gl-js took.
        if (_map.getLayer(layerId) != null) _map.removeLayer(layerId);
        throw _invalidProperty(
          layerId,
          error.property,
          properties[error.property],
          error.reason,
        );
      }
      if (_map.getLayer(layerId) != null) {
        // Logged, as maplibre-gl-js does without a listener.
        for (final message in others) {
          web.console.error(message.toJS);
        }
        return;
      }
      if (unknown.isEmpty || attempt > 0) {
        throw checks.layerNotAdded(layerId, others.firstOrNull);
      }
      kept = {
        for (final entry in kept.entries)
          if (!unknown.contains(entry.key)) entry.key: entry.value,
      };
    }
  }

  /// Removes the listeners [_addLayer] attached for an interactive layer.
  /// [Evented.off] finds the JS function [Evented.on] made from the same
  /// event type, layer id and tear-off, so the arguments must match exactly.
  void _detachLayerInteraction(String layerId) {
    _map.off('mouseenter', layerId, _handleLayerMouseMove);
    _map.off('mousemove', layerId, _handleLayerMouseMove);
    _map.off('mouseleave', layerId, _handleLayerMouseMove);
    if (_dragEnabled) {
      _map.off('mousedown', layerId, _onMouseDown);
      _map.off('touchstart', layerId, _onTouchStart);
    }
  }

  /// Forgets the features of [layerId] under the pointer. A removed layer
  /// fires no mouseleave, so each one still hovered gets its leave here, and
  /// the pointer cursor goes once nothing else is hovered.
  void _dropLayerHover(String layerId) {
    final hovered = _hoveredFeatureIdsByLayer.remove(layerId);
    if (hovered == null || hovered.isEmpty) return;
    final at = _lastHoverPosition;
    if (at != null) {
      for (final feature in hovered) {
        onFeatureHoverPlatform({
          'id': feature,
          'point': at.point,
          'latLng': at.latLng,
          'eventType': 'leave',
        });
      }
    }
    final isAnyFeatureHovered = _hoveredFeatureIdsByLayer.values.any(
      (hoveredFeatures) => hoveredFeatures.isNotEmpty,
    );
    if (!isAnyFeatureHovered) {
      _map.getCanvas().style.cursor = '';
    }
  }

  void _handleLayerMouseMove(Event e, String layerId) {
    // As text, the id the tap and drag callbacks get.
    final currentHoveredFeatures =
        e.features
            .map((f) => plainFeatureId(f.id)?.toString())
            .whereType<String>()
            .toList();
    final lastHoveredFeatures = _hoveredFeatureIdsByLayer[layerId] ?? [];
    final features = <String>{
      ...currentHoveredFeatures,
      ...lastHoveredFeatures,
    };
    _hoveredFeatureIdsByLayer[layerId] = currentHoveredFeatures;
    final point = Point<double>(e.point.x.toDouble(), e.point.y.toDouble());
    final latLng = LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble());
    _lastHoverPosition = (point: point, latLng: latLng);

    for (final feature in features) {
      final isCurrentlyHovered = currentHoveredFeatures.contains(feature);
      final isPreviouslyHovered = lastHoveredFeatures.contains(feature);
      late final String eventType;
      if (isCurrentlyHovered && isPreviouslyHovered) {
        eventType = 'move';
      } else if (isCurrentlyHovered && !isPreviouslyHovered) {
        eventType = 'enter';
        if (!_featureDrag.isDragging) {
          _map.getCanvas().style.cursor = 'pointer';
        }
      } else if (!isCurrentlyHovered && isPreviouslyHovered) {
        eventType = 'leave';
      }

      onFeatureHoverPlatform({
        'id': feature,
        'point': point,
        'latLng': latLng,
        'eventType': eventType,
      });
    }

    final isAnyFeatureHovered = _hoveredFeatureIdsByLayer.values.any(
      (hoveredFeatures) => hoveredFeatures.isNotEmpty,
    );
    if (isAnyFeatureHovered && !_featureDrag.isDragging) {
      _map.getCanvas().style.cursor = 'pointer';
    }
    if (!isAnyFeatureHovered) {
      _map.getCanvas().style.cursor = '';
    }
  }

  @override
  void setGestures({
    required bool rotateGesturesEnabled,
    required bool scrollGesturesEnabled,
    required bool tiltGesturesEnabled,
    required bool zoomGesturesEnabled,
    required bool doubleClickZoomEnabled,
    PanInertia panInertia = PanInertia.normal,
  }) {
    if (rotateGesturesEnabled &&
        scrollGesturesEnabled &&
        tiltGesturesEnabled &&
        zoomGesturesEnabled) {
      _map.keyboard.enable();
    } else {
      _map.keyboard.disable();
    }

    if (scrollGesturesEnabled) {
      // Pan inertia is an option of dragPan.enable(), so it is applied here.
      // maplibre-gl-js glides for speed / (deceleration * linearity) s, with
      // speed capped at maxSpeed px/s:
      // - none: maxSpeed 0, no glide.
      // - short: deceleration 5000, half the time and distance of normal.
      // - normal: no options, the defaults (linearity 0.3, deceleration 2500,
      //   maxSpeed 1400).
      switch (panInertia) {
        case PanInertia.none:
          _map.dragPan.enable(maxSpeed: 0);
        case PanInertia.short:
          _map.dragPan.enable(deceleration: 5000);
        case PanInertia.normal:
          _map.dragPan.enable();
      }
    } else {
      _map.dragPan.disable();
    }

    if (zoomGesturesEnabled) {
      _map.doubleClickZoom.enable();
      _map.boxZoom.enable();
      _map.scrollZoom.enable();
      _map.touchZoomRotate.enable();
    } else {
      _map.doubleClickZoom.disable();
      _map.boxZoom.disable();
      _map.scrollZoom.disable();
      _map.touchZoomRotate.disable();
    }

    if (doubleClickZoomEnabled) {
      _map.doubleClickZoom.enable();
    } else {
      _map.doubleClickZoom.disable();
    }

    if (rotateGesturesEnabled) {
      _map.touchZoomRotate.enableRotation();
    } else {
      _map.touchZoomRotate.disableRotation();
    }

    // dragRotate is shared by both gestures
    if (tiltGesturesEnabled && rotateGesturesEnabled) {
      _map.dragRotate.enable();
    } else {
      _map.dragRotate.disable();
    }
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    final json = normalizeSource(properties.toJson());
    final type = json['type'] as String?;
    // A string is the url of the data.
    final data = json['data'];
    if (type == 'geojson' && data != null && data is! String) {
      final reason = geoJsonError(data);
      if (reason != null) throw invalidGeoJson(sourceId, reason);
    }
    _ensureStyleReady();
    _ensureNewSourceId(sourceId);
    if (!checks.canBuildSource(type, json)) {
      throw PlatformException(
        code: 'INVALID_ARGUMENT',
        message:
            "Source '$sourceId' cannot be built from its properties as a "
            "'$type' source.",
      );
    }
    // An object in GeoJSON data goes in as what its toJson() returns, as on
    // Android and iOS.
    final plain = type == 'geojson' ? jsonValueOf(data) : null;
    if (plain is Map) {
      // Data the plugin sets keeps its feature ids.
      final (jsData, features) = _geoJsonData(plain);
      _addGeoJsonSource(
        sourceId,
        jsifyJson({...json}..remove('data'))! as JSObject,
        jsData,
        features,
      );
      return;
    }
    (_map.jsObject as JSObject).callMethod<JSAny?>(
      'addSource'.toJS,
      sourceId.toJS,
      jsifyJson(json),
    );
  }

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) async {
    // Checked in the order of Android and iOS: the id, the corners, then the
    // bytes.
    _ensureStyleReady();
    _ensureNewSourceId(imageSourceId);
    _checkLatLngs(_cornerLatLngs(coordinates));
    final image = await _imageBlob(bytes);
    // The decoding yields, so the style or the id may have changed since.
    _ensureStyleReady();
    _ensureNewSourceId(imageSourceId);
    final url = web.URL.createObjectURL(image);
    try {
      _map.addSource(imageSourceId, <String, dynamic>{
        'type': 'image',
        'url': url,
        'coordinates': _corners(coordinates),
      });
    } catch (_) {
      _revokeUrl(url);
      rethrow;
    }
    _imageUrls[imageSourceId] = url;
  }

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {
    _ensureStyleReady();
    _imageSource(imageSourceId);
    if (coordinates != null) _checkLatLngs(_cornerLatLngs(coordinates));
    // Decoded before anything changes, so a call that fails changes nothing.
    final image = bytes == null ? null : await _imageBlob(bytes);
    _ensureStyleReady();
    final source = _imageSource(imageSourceId);
    // updateImage would move the corners only once the image has loaded.
    if (coordinates != null) {
      source.callMethod<JSAny?>(
        'setCoordinates'.toJS,
        jsify(_corners(coordinates)),
      );
    }
    if (image != null) {
      final url = web.URL.createObjectURL(image);
      source.callMethod<JSAny?>('updateImage'.toJS, jsify({'url': url}));
      _forgetImageUrl(imageSourceId);
      _imageUrls[imageSourceId] = url;
    }
  }

  /// The object URL of the image each image source shows from bytes, by
  /// source id. [getSourceProperties] leaves it out, as Android and iOS have
  /// no url for such a source.
  final _imageUrls = <String, String>{};

  /// Revokes the object URL of the image the image source [sourceId] shows
  /// from bytes, if any.
  void _forgetImageUrl(String sourceId) {
    final url = _imageUrls.remove(sourceId);
    if (url != null) _revokeUrl(url);
  }

  /// Revokes the object URLs of every image source shown from bytes.
  void _forgetImageUrls() {
    _imageUrls.values.forEach(_revokeUrl);
    _imageUrls.clear();
  }

  /// Frees the blob behind the object URL [url].
  static void _revokeUrl(String url) => web.URL.revokeObjectURL(url);

  /// The image source [imageSourceId] as maplibre-gl-js holds it. Throws
  /// `SOURCE_NOT_FOUND` when the style has no image source with that id.
  JSObject _imageSource(String imageSourceId) {
    final source = _jsSource(imageSourceId);
    if (source == null || _sourceType(imageSourceId) != 'image') {
      throw PlatformException(
        code: 'SOURCE_NOT_FOUND',
        message: 'Image source $imageSourceId not found.',
      );
    }
    return source;
  }

  /// The four corners of [quad].
  static List<LatLng> _cornerLatLngs(LatLngQuad quad) => [
    quad.topLeft,
    quad.topRight,
    quad.bottomRight,
    quad.bottomLeft,
  ];

  /// The corners of an image source in the order maplibre-gl-js takes them:
  /// top left, top right, bottom right, bottom left, each as [lng, lat].
  static List<List<double>> _corners(LatLngQuad quad) => [
    for (final corner in _cornerLatLngs(quad))
      [corner.longitude, corner.latitude],
  ];

  /// [bytes] as a blob, for the object URL an image source loads. Throws
  /// `INVALID_IMAGE` for bytes the browser cannot decode, which
  /// maplibre-gl-js would report only later, through an error event.
  static Future<web.Blob> _imageBlob(Uint8List bytes) async {
    final blob = web.Blob([bytes.toJS].toJS);
    try {
      final bitmap = await web.window.createImageBitmap(blob).toDart;
      bitmap.close();
    } catch (_) {
      throw PlatformException(
        code: 'INVALID_IMAGE',
        message: 'Failed to decode image bytes.',
      );
    }
    return blob;
  }

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) {
    return _addLayer(
      imageSourceId,
      imageLayerId,
      const {},
      'raster',
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) {
    return _addLayer(
      imageSourceId,
      imageLayerId,
      const {},
      'raster',
      belowLayerId: belowLayerId,
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {
    // MapLibre GL JS expresses content insets as camera `padding`. easeTo with
    // a zero duration applies it immediately (the non-animated case).
    //
    // The event data matters: GeolocateControl drops its follow lock on any
    // movestart it did not cause, so padding a map for a bottom sheet would
    // otherwise stop it following the user and report a tracking dismissal.
    // Flagging the move the way the control flags its own keeps the lock.
    _cancelCameraAnimation();
    _map.easeTo(
      {
        'padding': {
          'top': insets.top,
          'bottom': insets.bottom,
          'left': insets.left,
          'right': insets.right,
        },
        'duration': animated ? _contentInsetsDuration.inMilliseconds : 0,
      },
      {'geolocateSource': true},
    );
    // easeTo is fire-and-forget, so without this the future resolves while the
    // camera is still moving and a caller that awaits setPadding and then reads
    // the camera, or fits bounds against the new padding, sees the state from
    // before the ease. Waiting out the duration rather than the `moveend` event
    // on purpose: a map disposed mid-animation, or a second move arriving over
    // this one, must not leave the caller awaiting an event that never comes.
    if (animated) await Future<void>.delayed(_contentInsetsDuration);
  }

  /// How long an animated content-inset change takes. MapLibre GL JS has no
  /// default of its own for this (`easeTo` requires a duration), and
  /// `updateContentInsets` takes no duration to pass through, so the value is
  /// fixed here and matches the SDK's usual short camera ease.
  static const _contentInsetsDuration = Duration(milliseconds: 300);

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) async {
    final reason = geoJsonFeatureError(geojsonFeature);
    if (reason != null) throw invalidGeoJsonFeature(sourceId, reason);
    final source = _geoJsonSource(sourceId, 'setGeoJsonFeature');
    // Nothing changes in a source whose data this controller did not set.
    final features = _addedFeaturesByLayer[sourceId];
    // A feature without an id replaces nothing.
    final id = _featureIdKey(_jsonId(geojsonFeature));
    if (features == null || id == null) return;
    final index = features.indexWhere((feature) => feature.id == id);
    if (index < 0) return;
    final updated = List.of(features);
    final (feature, replaced) = _geoJsonData(geojsonFeature);
    if (_keepFeatureIds(sourceId)) _copyFeatureIds(replaced);
    updated[index] = (id: id, feature: feature);
    _addedFeaturesByLayer[sourceId] = updated;
    await source.setData(_featureCollection(updated));
  }

  @override
  Future<void> setFeatureState(
    String sourceId,
    String featureId,
    Map<String, dynamic> state, {
    String? sourceLayer,
  }) async {
    _ensureFeatureStateSource(sourceId, sourceLayer);
    if (!checks.isJsonValue(state)) {
      throw checks.featureStateNotJson(sourceId, featureId);
    }
    final feature = FeatureIdentifierJsImpl.of(
      source: sourceId,
      id: featureId.jsify(),
      sourceLayer: sourceLayer,
    );

    _map.setFeatureState(feature, state.jsify());
  }

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) async {
    // A stateKey lives inside one feature's state, so without a featureId
    // there is nothing to remove it from. maplibre-gl-js only fires an error
    // event here and leaves the state alone, which the caller never sees, so
    // raise what Android raises for the same call instead.
    if (featureId == null && stateKey != null) {
      throw PlatformException(
        code: 'INVALID_ARGUMENT',
        message:
            "removeFeatureState with a 'stateKey' also requires the "
            "'featureId' that owns the key.",
      );
    }

    _ensureFeatureStateSource(sourceId, sourceLayer);
    final feature = FeatureIdentifierJsImpl.of(
      source: sourceId,
      id: featureId.jsify(),
      sourceLayer: sourceLayer,
    );

    _map.removeFeatureState(feature, stateKey);
  }

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) async {
    _ensureFeatureStateSource(sourceId, sourceLayer);
    final feature = FeatureIdentifierJsImpl.of(
      source: sourceId,
      id: featureId.jsify(),
      sourceLayer: sourceLayer,
    );

    // Not `dartify()`: for a JS object that returns a Map<Object?, Object?>,
    // so casting it to Map<String, dynamic> threw on every call that found a
    // state. dartifyMap builds the typed map this signature promises.
    final state = dartifyMap(_map.getFeatureState(feature));

    // maplibre-gl-js answers {} for a feature that has no state at all, while
    // Android replies null and the return type is nullable so callers can tell
    // the two apart. Report the absence the same way here. A state explicitly
    // set to {} is indistinguishable from no state on this platform, and reads
    // as absent.
    return state.isEmpty ? null : state;
  }

  @override
  void resizeWebMap() {
    _onMapResize();
  }

  @override
  void forceResizeWebMap() {
    _map.resize();
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    _ensureStyleReady();
    _ensureLayerExists(layerId);
    _map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
  }

  @override
  Future<List<String>> setLayersVisibility(
    List<String> layerIds,
    bool visible,
  ) async {
    // An empty list needs no style. Unknown ids are skipped and returned.
    if (layerIds.isEmpty) return [];
    _ensureStyleReady();
    final visibility = visible ? 'visible' : 'none';
    final missing = <String>[];
    for (final layerId in layerIds) {
      if (_map.getLayer(layerId) == null) {
        if (!missing.contains(layerId)) missing.add(layerId);
        continue;
      }
      _map.setLayoutProperty(layerId, 'visibility', visibility);
    }
    return missing;
  }

  @override
  Future<void> setLayerZoomRange(
    String layerId,
    double minzoom,
    double maxzoom,
  ) async {
    // maplibre-gl-js takes any range, so the values Android and iOS reject
    // are rejected here too.
    if (!(minzoom >= 0 && maxzoom <= 24 && minzoom <= maxzoom)) {
      throw PlatformException(
        code: 'INVALID_ARGUMENT',
        message:
            'Invalid zoom range [$minzoom, $maxzoom]: both must be within 0 '
            'and 24, with minzoom not above maxzoom.',
      );
    }
    _ensureStyleReady();
    _ensureLayerExists(layerId);
    _map.setLayerZoomRange(layerId, minzoom, maxzoom);
  }

  @override
  Future getFilter(String layerId) async {
    _checkFilterable(layerId);
    return withoutFeatureIds(_map.getFilter(layerId));
  }

  /// The layer types Android and iOS can filter.
  static const _filterableLayerTypes = {
    'circle',
    'fill',
    'fill-extrusion',
    'heatmap',
    'line',
    'symbol',
  };

  /// Throws the errors Android and iOS give for a layer that is missing or
  /// cannot be filtered. GL JS only logs the first and accepts the second.
  void _checkFilterable(String layerId) {
    final layer = _map.getLayer(layerId);
    if (layer == null) {
      throw PlatformException(
        code: 'LAYER_NOT_FOUND_ERROR',
        message: 'Layer not found',
        details: 'Layer with id $layerId not found.',
      );
    }
    final type =
        (layer as JSObject).getProperty<JSString?>('type'.toJS)?.toDart;
    if (!_filterableLayerTypes.contains(type)) {
      throw PlatformException(
        code: 'INVALID_LAYER_TYPE',
        message: 'Invalid layer type',
        details: "Layer '$layerId' does not support filtering.",
      );
    }
  }

  @override
  Future<List> getLayerIds() async {
    final layers = _map.getLayers();
    return layers.map((layer) => layer.id).toList();
  }

  @override
  Future<List> getSourceIds() async {
    final sourceIds = _map.getSourceIds();
    return sourceIds;
  }

  @override
  Future<Map<String, dynamic>?> getLayerProperties(String layerId) async {
    _ensureStyleReady();
    // The serialized style already holds each layer in MapLibre style-spec
    // form (id/type/source/paint/layout/...), which is exactly the contract,
    // so we read it from there rather than reassembling it from getters.
    final layers = _styleMap()?['layers'];
    if (layers is! List) return null;
    for (final layer in layers) {
      if (layer is Map && layer['id'] == layerId) {
        final shaped =
            withoutFeatureIds(_styleShaped(layer))! as Map<String, dynamic>;
        // Android and iOS leave out a zoom range at the spec defaults, which
        // maplibre-gl-js serializes once set, by setLayerZoomRange or the
        // style itself.
        final minzoom = shaped['minzoom'];
        if (minzoom is num && minzoom <= 0) shaped.remove('minzoom');
        final maxzoom = shaped['maxzoom'];
        if (maxzoom is num && maxzoom >= 24) shaped.remove('maxzoom');
        return shaped;
      }
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getSourceProperties(String sourceId) async {
    _ensureStyleReady();
    final sources = _styleMap()?['sources'];
    if (sources is! Map) return null;
    final source = sources[sourceId];
    if (source is! Map) return null;
    final shaped = withoutFeatureIdsInSource(_styleShaped(source));
    if (_imageUrls.containsKey(sourceId)) shaped.remove('url');
    return shaped;
  }

  /// The current style as a Dart map (style-spec shaped), or null if unset.
  Map<String, dynamic>? _styleMap() {
    // getStyleObject, not getStyle: the latter is typed as the @staticInterop
    // StyleJsImpl, which dartify cannot walk under dart2wasm, so both callers
    // failed there with "Attempt to execute code removed by Dart AOT compiler
    // (TFA)" while working fine on JavaScript.
    final styleJs = _map.getStyleObject();
    if (styleJs == null) return null;
    return dartifyMap(styleJs);
  }

  /// A style entry in the shape every platform answers with.
  ///
  /// [shapeStyleProperties] is the shared rule, applied to the native replies
  /// too, so `minzoom` and a `fill-opacity` of `1.0` read the same here as they
  /// do on Android and iOS. It lives in the platform interface because getting
  /// the two sides to agree is the whole point of it.
  Map<String, dynamic> _styleShaped(Map<dynamic, dynamic> entry) =>
      shapeStyleProperties(entry);

  @override
  Future<bool?> getLayerVisibility(String layerId) async {
    _ensureStyleReady();
    if (_map.getLayer(layerId) == null) return null;
    final property = _map.getLayoutProperty(layerId, 'visibility');
    if (property == null) return true;
    if (property is String) return property != 'none';
    return true;
  }

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() async {
    final complete = Completer<void>();
    _map.once('idle', (_) => complete.complete());
    return complete.future;
  }

  @override
  Future<void> waitUntilMapTilesAreLoaded() async {
    if (_map.areTilesLoaded()) {
      return;
    }

    final tilesLoadedCompleter = Completer<void>();
    late void Function(dynamic) listener;
    listener = (_) {
      if (_map.areTilesLoaded()) {
        _map.off('sourcedata', listener);
        if (!tilesLoadedCompleter.isCompleted) {
          tilesLoadedCompleter.complete();
        }
      }
    };
    _map.on('sourcedata', listener);

    await tilesLoadedCompleter.future;
  }

  @override
  Future<ui.Size> setWebMapToCustomSize(ui.Size size) async {
    final initialSize = ui.Size(
      _map.getContainer().clientWidth.toDouble(),
      _map.getContainer().clientHeight.toDouble(),
    );

    _map.getContainer().style.width = '${size.width}px';
    _map.getContainer().style.height = '${size.height}px';
    _map.resize();

    await waitUntilMapIsIdleAfterMovement();
    return initialSize;
  }

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) {
    // A snapshot waits for map events that a newer call or a dispose can keep
    // from coming. Android and iOS answer it then, so web does too.
    _cancelSnapshot(
      'SNAPSHOT_ERROR',
      'A newer takeSnapshot call cancelled this one.',
    );
    final answer = Completer<Uint8List>();
    _pendingSnapshot = answer;
    bool current() => identical(_pendingSnapshot, answer);
    unawaited(
      _snapshot(width, height, current).then(
        (bytes) {
          if (!current() || bytes == null) return;
          _pendingSnapshot = null;
          answer.complete(bytes);
        },
        onError: (Object error, StackTrace stack) {
          if (!current()) return;
          _pendingSnapshot = null;
          answer.completeError(error, stack);
        },
      ),
    );
    return answer.future;
  }

  /// The answer of the [takeSnapshot] call still running.
  Completer<Uint8List>? _pendingSnapshot;

  /// The size of the map before a [takeSnapshot] call with a size resized it,
  /// until the size is put back.
  ui.Size? _sizeBeforeSnapshot;

  /// Answers the [takeSnapshot] call still running, if any, with the error
  /// [code] and [message].
  void _cancelSnapshot(String code, String message) {
    final pending = _pendingSnapshot;
    _pendingSnapshot = null;
    pending?.completeError(PlatformException(code: code, message: message));
  }

  /// The snapshot of a [takeSnapshot] call, at [width] by [height] when both
  /// are set. Null once [current] is false: a newer call or a dispose has
  /// answered the call, and the size is left for the newer call to put back.
  Future<Uint8List?> _snapshot(
    int? width,
    int? height,
    bool Function() current,
  ) async {
    final sized = width != null && height != null;
    if (sized) {
      final container = _map.getContainer();
      _sizeBeforeSnapshot ??= ui.Size(
        container.clientWidth.toDouble(),
        container.clientHeight.toDouble(),
      );
      await setWebMapToCustomSize(ui.Size(width.toDouble(), height.toDouble()));
      if (!current()) return null;
      await waitUntilMapTilesAreLoaded();
    } else if (_sizeBeforeSnapshot case final size?) {
      // A cancelled call left the map at the size it asked for.
      _sizeBeforeSnapshot = null;
      await setWebMapToCustomSize(size);
    }
    if (!current()) return null;
    final dataUrl = await _renderedImage();
    if (!current()) return null;
    if (_sizeBeforeSnapshot case final size? when sized) {
      _sizeBeforeSnapshot = null;
      await setWebMapToCustomSize(size);
    }
    return base64Decode(dataUrl.split(',').last);
  }

  /// The map as a PNG data URL, read while it renders: the WebGL context does
  /// not keep its drawing buffer, for speed, so the canvas is blank between
  /// renders.
  Future<String> _renderedImage() {
    final completer = Completer<String>();
    _map.once('render', (_) {
      completer.complete(_map.getCanvas().toDataUrl('image/png'));
    });
    _map.triggerRepaint();
    return completer.future;
  }
}
