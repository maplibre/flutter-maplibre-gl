import Flutter
import MapLibre
#if canImport(maplibre_gl_objc)
    import maplibre_gl_objc
#endif

class MapLibreMapController: NSObject, FlutterPlatformView, MLNMapViewDelegate, MapLibreMapOptionsSink,
    UIGestureRecognizerDelegate
{
    private var registrar: FlutterPluginRegistrar
    /// The messenger and the suffix, the view id, of this map's Pigeon
    /// channels, kept to unregister the Dart calls in `deinit`.
    private let binaryMessenger: FlutterBinaryMessenger
    private let channelSuffix: String
    /// Takes this map's Dart calls. It holds the controller weakly.
    private let hostApi = MapHostApi()
    /// Sends this map's events to Dart.
    private let eventApi: MapLibreMapFlutterApi
    /// `eventApi` while this map holds its channels: after a hot restart a
    /// newer map with the same view id takes them over, and this one's late
    /// events would reach it.
    private var flutterApi: MapLibreMapFlutterApi? {
        hostApi.ownsChannels(binaryMessenger: binaryMessenger, messageChannelSuffix: channelSuffix)
            ? eventApi : nil
    }

    private var mapView: MLNMapView
    /// The snapshot being taken, if any.
    private var activeSnapshot: Snapshot?
    private var isMapReady = false
    private var dragEnabled = true
    private var featureTapsTriggersMapClick = false
    // Whether MapLibre fades symbols as it places them. A style holds its own
    // setting, so this is applied again on every style load.
    private var symbolPlacementTransitionsEnabled = true
    private var isFirstStyleLoad = true
    private var onStyleLoadedCalled = false
    /// The mapWaitForMap calls waiting for the style, answered together as on
    /// Android: keeping only the last one left the others unanswered.
    private var mapReadyResults: [FlutterResult] = []
    private var previousDragCoordinate: CLLocationCoordinate2D?
    private var originDragCoordinate: CLLocationCoordinate2D?
    private var dragFeature: MLNFeature?
    /// The pan recognizer this controller adds for feature drags.
    private var featureDragPan: UIPanGestureRecognizer?
    /// Where the first finger of the current feature drag pan came down.
    private var featureDragTouchDown: CGPoint?

    /// `initialCameraPosition` from the creation params, kept until the view has
    /// a size. A camera set on a 0x0 view gets altitude 0 for every zoom, which
    /// MLNMapView takes for "no change" and drops, so the map stays at zoom 0.
    private var pendingInitialCamera: PgCameraPosition?
    private var trackCameraPosition = false
    /// The camera position last sent to `cameraOnMove`, or the one the current camera change
    /// started from. Nil while the position is not tracked.
    private var lastMovePosition: PgCameraPosition?
    private let cameraAnimations = CameraAnimationTracker()
    /// Completion handlers given to MLNMapView that have not run yet, each with
    /// the answer `deinit` gives if the map goes away first.
    private var completionsAnsweredOnDispose: [Int: () -> Void] = [:]
    private var nextCompletionId = 0
    private var myLocationEnabled = false
    private var manualLocationSource = false
    /// Colors of the user-location puck, from the Dart `MyLocationStyle`.
    private var locationPuckStyle = LocationPuckStyle()
    /// Whether the puck view's tint was ever set from `locationPuckStyle`. Until
    /// then the SDK's own look is left untouched.
    private var locationPuckTinted = false
    private lazy var manualLocationManager = ManualLocationManager()
    /// The last location the app pushed, shown again when myLocationEnabled
    /// turns back on.
    private var lastManualLocation: CLLocation?
    private var scrollingEnabled = true
    private var isAdjustingCameraProgrammatically = false

    private var interactiveFeatureLayerIds = Set<String>()
    private var addedShapesByLayer = [String: MLNShape]()
    /// The calls waiting for the view to have a size, in the order they came,
    /// each with the result that answers it.
    private var callsWaitingForSize: [(call: (MapLibreMapController) -> Void, result: FlutterResult)] = []
    /// Layers never added to a style, one per layer type, that layer property
    /// values are tried on first.
    private var propertyCheckLayers: [String: MLNStyleLayer] = [:]
    /// What this plugin changed on each layer since the style loaded, by
    /// layer id. MapLibre on iOS reads a property that was never set as its
    /// default value, and a filter back through NSPredicate, which rewrites it.
    private var layerChanges: [String: LayerChanges] = [:]
    /// The attribution each source this plugin added was given, by source id.
    /// MapLibre on iOS keeps it rewritten as HTML of its own.
    private var sourceAttributions: [String: String] = [:]
    /// Whether the current style was set as JSON rather than by URL.
    private var styleIsJSON = false

    private struct LayerChanges {
        /// Whether this plugin added the layer, rather than the style.
        var isAdded = false
        /// The names of the paint and layout properties set on the layer.
        var propertyNames: Set<String> = []
        /// The filter as it was set, NSNull for none, or nil for the style's.
        var filter: Any? = nil
    }

    // GPS pulse: start/stop location updates on a timer to save battery.
    private var locationPulseTimer: Timer?
    private var locationPulseWindowTimer: Timer?
    private var locationUpdateIntervalMs: Int = 0
    private var locationPulseWindowMs: Int = MapLibreMapController.defaultPulseWindowMs
    static let defaultPulseWindowMs: Int = 5000

    /// Duration used for `locationComponentSetTrackingCameraOptions` when Dart sends
    /// none. Matches the MapLibre Android location component's own tilt-while-tracking
    /// default, so the two platforms animate alike.
    static let defaultTrackingTiltDurationMs: Int = 1250

    /// Duration of `cameraAnimate` and `cameraEase` when Dart sends none: the one
    /// `setCamera(_:animated:)` uses, which has no completion handler, and the Android default.
    static let defaultCameraAnimationDuration: TimeInterval = 0.3

    private var doubleTapRecognizers: [UITapGestureRecognizer] = []

    private var userFps: MLNMapViewPreferredFramesPerSecond = .default
    private var pausedByDart = false
    private var isBackgroundPaused = false

    func view() -> UIView {
        return mapView
    }

    deinit {
        // The Android controller tears the map down explicitly in `dispose()`
        // (`mapView.onStop()` / `onDestroy()`), but on iOS a `FlutterPlatformView`
        // gets no dispose callback, so `MLNMapView` cleanup relies entirely on
        // ARC reclaiming this controller. `MLNMapView`'s renderer runs off a
        // `CADisplayLink` that is retained through the run loop until the view
        // leaves its window, and it keeps tile-fetch connections open. When a
        // host creates a new map view per screen/route (e.g. a basemap switch),
        // the old engines can linger and contend for GPU/network resources.
        // Drive the view out of its window and drop the remaining references so
        // the engine is reclaimed promptly when the platform view is removed.
        NotificationCenter.default.removeObserver(self)
        // Fails the mapWaitForMap calls still waiting for the style, whose Dart
        // futures would otherwise never complete.
        let waitingForMap = mapReadyResults
        mapReadyResults.removeAll()
        for waitingResult in waitingForMap {
            waitingResult(FlutterError(
                code: "MAP_DISPOSED",
                message: "The map was disposed before it finished being created",
                details: nil
            ))
        }
        // A call waiting for a size the view never got, whose Dart future would
        // otherwise never complete.
        let waitingCalls = callsWaitingForSize
        callsWaitingForSize.removeAll()
        for waiting in waitingCalls {
            waiting.result(MapHostApi.disposedError())
        }
        cancelSnapshot(FlutterError(
            code: "MAP_DISPOSED",
            message: "The map was disposed before the snapshot was ready.",
            details: nil
        ))
        // Leaves the handlers alone if a newer map with the same view id
        // already took the channels over, as after a hot restart.
        hostApi.unregister(binaryMessenger: binaryMessenger, messageChannelSuffix: channelSuffix)
        mapView.delegate = nil
        if let recognizers = mapView.gestureRecognizers {
            for recognizer in recognizers {
                mapView.removeGestureRecognizer(recognizer)
            }
        }
        // The map stops animating once out of its window and never runs the completion handler,
        // so answer a camera call still waiting for it with false, as Android and web do.
        cameraAnimations.cancelRunning()
        let disposedAnswers = completionsAnsweredOnDispose.values
        completionsAnsweredOnDispose.removeAll()
        disposedAnswers.forEach { $0() }
        locationPulseTimer?.invalidate()
        locationPulseWindowTimer?.invalidate()
        mapView.removeFromSuperview()
    }

    private var styleIsReady: Bool {
        return onStyleLoadedCalled && mapView.style != nil
    }

    private static func createMapView(
        styleString: String?,
        frame: CGRect,
        registrar: FlutterPluginRegistrar
    ) -> MLNMapView {
        if let styleString = styleString {
            if Self.styleStringIsJSON(styleString) {
                return LocationPuckMapView(frame: frame, styleJSON: styleString)
            }

            if let url = Self.styleStringAsURL(
                styleString,
                registrar: registrar
            ) {
                return LocationPuckMapView(frame: frame, styleURL: url)
            }
        }

        // Fallback to default if neither JSON nor valid URL
        NSLog(
            """
            Warning: MapLibreMapController - Initializing map view with \
            default style. This capability will be removed in a future release.
            """
        )
        // https://github.com/maplibre/maplibre-native/issues/709
        return LocationPuckMapView(frame: frame)
    }

    init(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        registrar: FlutterPluginRegistrar
    ) {
        // Decoded by MapLibreMapFactory.createArgsCodec.
        let params = args as? PgCreationParams
        mapView = Self.createMapView(
            styleString: params?.styleString,
            frame: frame,
            registrar: registrar
        )

        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let styleString = params?.styleString {
            styleIsJSON = Self.styleStringIsJSON(styleString)
        }
        self.registrar = registrar
        let messenger = registrar.messenger()
        let suffix = "\(viewId)"
        binaryMessenger = messenger
        channelSuffix = suffix
        eventApi = MapLibreMapFlutterApi(binaryMessenger: messenger, messageChannelSuffix: suffix)

        super.init()

        hostApi.controller = self
        hostApi.register(binaryMessenger: binaryMessenger, messageChannelSuffix: channelSuffix)

        mapView.delegate = self
        (mapView as? LocationPuckMapView)?.onTintColorDidChange = { [weak self] in
            self?.applyLocationPuckTint()
        }
        (mapView as? LocationPuckMapView)?.onLayout = { [weak self] in
            // After the layout pass, so the map has taken its new size.
            guard let self = self, !self.callsWaitingForSize.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                self?.runCallsWaitingForSize()
            }
        }

        let singleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleMapTap(sender:))
        )
        for recognizer in mapView.gestureRecognizers!
        where (recognizer as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 {
            singleTap.require(toFail: recognizer)
            doubleTapRecognizers.append(recognizer as! UITapGestureRecognizer)
        }
        mapView.addGestureRecognizer(singleTap)

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleMapLongPress(sender:))
        )
        var longPressRecognizerAdded = false

        // Flutter PlatformView hands us a zero-sized frame on cold launch.
        // Any setter that touches the C++ map's camera/bounds (setCenter,
        // maximumScreenBounds, min/max zoom, showsUserLocation → flyTo on
        // cached CL fix) cascades into `constrainCameraAndZoomToBounds` →
        // `Projection::unproject` on a 0×0 viewport → NaN → the `mbgl::LatLng`
        // ctor throws `std::domain_error`, which libc++abi cannot unwind
        // through Swift → SIGABRT (~150 ms after cold launch via force-quit
        // + relaunch). Defer the options-apply block to the next runloop turn;
        // Flutter calls `setFrame` with the real size by then. (issue #819)
        let applyArgs: () -> Void = { [weak self] in
            guard let self = self, let params = params else { return }

            Convert.interpretMapLibreMapOptions(options: params.options, delegate: self)
            self.applyInitialCameraIfNeeded()
        }
        // Set before anything can run, so no Dart call or delegate callback can
        // see the map without it and no later apply can undo an app move.
        pendingInitialCamera = params?.initialCameraPosition
        if mapView.frame.size.equalTo(.zero) {
            DispatchQueue.main.async(execute: applyArgs)
        } else {
            applyArgs()
        }

        if let params = params {
            dragEnabled = params.dragEnabled

            if let iosLongClickDurationMs = params.iosLongClickDurationMs {
                longPress.minimumPressDuration = TimeInterval(iosLongClickDurationMs) / 1000
                mapView.addGestureRecognizer(longPress)
                longPressRecognizerAdded = true
            }
        }
        if dragEnabled {
            let pan = UIPanGestureRecognizer(
                target: self,
                action: #selector(handleMapPan(sender:))
            )
            pan.delegate = self
            mapView.addGestureRecognizer(pan)
            featureDragPan = pan
        }

        if(!longPressRecognizerAdded) {
            mapView.addGestureRecognizer(longPress)
            longPressRecognizerAdded = true
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // Pausing the render loop before the OS suspends the process prevents a
    // SIGSEGV in PMTilesFileSource, which runs file I/O on a background thread
    // that can be torn down mid-read during app backgrounding (#833).
    // didEnterBackground (not willResignActive) is used so transient interruptions
    // like incoming call banners or Control Center do not freeze the map.
    @objc private func appDidEnterBackground() {
        isBackgroundPaused = true
        mapView.preferredFramesPerSecond = MLNMapViewPreferredFramesPerSecond(rawValue: 0)
        // Location updates stop in the background as on Android (#1094), whether
        // or not the app has a location background mode for other reasons. The
        // user-location annotation stays at its last position.
        if myLocationEnabled && !manualLocationSource {
            stopLocationUpdates()
        }
    }

    @objc private func appWillEnterForeground() {
        isBackgroundPaused = false
        // MLNMapView starts Core Location again on foreground. This restarts the
        // pulse, or stops the updates again for a map paused from Dart.
        if myLocationEnabled && !manualLocationSource {
            restartLocationPulseIfNeeded()
        }
        guard !pausedByDart else { return }
        mapView.preferredFramesPerSecond = userFps
    }

    func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    // The pan only begins after the finger has moved, so remember where the
    // first finger came down to look up the feature there, like Android.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        if gestureRecognizer === featureDragPan, gestureRecognizer.numberOfTouches == 0 {
            featureDragTouchDown = touch.location(in: mapView)
        }
        return true
    }

    /// What a Dart call does with the camera, which decides whether it waits
    /// for the view to have a size.
    enum CallKind {
        /// Runs at once.
        case plain
        /// Moves the camera, or changes what it may show: the camera calls,
        /// setCameraBounds, the content insets and the map options. On a
        /// zero-sized frame, such as a move from Dart onMapCreated before
        /// layout, the projection yields NaN and mbgl::LatLng aborts the app,
        /// so it waits for a real frame (#819).
        case movesCamera
        /// Reads the camera or the projection. While the initial camera waits
        /// for a size these calls wait too, or they would report zoom 0.
        case readsCamera
    }

    /// Runs a Dart call on this map, after the initial camera, so a camera move
    /// from Dart lands on top of it.
    ///
    /// A call that waits for the view's size runs once the view has laid out
    /// with one, after the calls that waited before it. If the map is disposed
    /// first, `result` answers MAP_DISPOSED. The controller is passed to
    /// `call`, not captured, so a waiting call does not keep a disposed map
    /// alive.
    func runCall(
        _ kind: CallKind,
        result: @escaping FlutterResult,
        _ call: @escaping (MapLibreMapController) -> Void
    ) {
        if kind == .movesCamera || (kind == .readsCamera && pendingInitialCamera != nil) {
            if mapView.frame.size.equalTo(.zero) {
                callsWaitingForSize.append((call: call, result: result))
                return
            }
            runCallsWaitingForSize()
        }
        applyInitialCameraIfNeeded()
        call(self)
    }

    /// Runs the calls that waited for the view to have a size, once it has one.
    private func runCallsWaitingForSize() {
        guard !callsWaitingForSize.isEmpty, !mapView.frame.size.equalTo(.zero) else { return }
        let waiting = callsWaitingForSize
        callsWaitingForSize.removeAll()
        applyInitialCameraIfNeeded()
        for waitingCall in waiting {
            waitingCall.call(self)
        }
    }

    // MARK: Dart calls: map

    func mapWaitForMap(result: @escaping FlutterResult) {
        if isMapReady {
            result(nil)
            // Only fire onStyleLoaded here once the map is ready, on the first style load.
            if isFirstStyleLoad {
                isFirstStyleLoad = false
                onStyleLoadedCalled = true
                // Defer the callback to the next run loop iteration to avoid race conditions
                let api = flutterApi
                DispatchQueue.main.async {
                    api?.mapOnStyleLoaded { _ in }
                }
            }
        } else {
            mapReadyResults.append(result)
        }
    }

    func mapUpdate(options: PgMapOptions, result: @escaping FlutterResult) {
        Convert.interpretMapLibreMapOptions(options: options, delegate: self)
        // Nil when the map does not track the camera position. A map without a
        // size has yet to show its initial camera, so that is the one it reports.
        guard let camera = getCamera() else {
            result(nil)
            return
        }
        result(pendingInitialCamera ?? camera.toPigeon(mapView: mapView))
    }

    func mapInvalidateAmbientCache(result: @escaping FlutterResult) {
        MLNOfflineStorage.shared.invalidateAmbientCache {
            error in
            if let error = error {
                // An NSError is not encodable by the standard codec.
                result(FlutterError(
                    code: "AMBIENT_CACHE_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }

    func mapClearAmbientCache(result: @escaping FlutterResult) {
        MLNOfflineStorage.shared.clearAmbientCache {
            error in
            if let error = error {
                result(FlutterError(
                    code: "AMBIENT_CACHE_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }

    func mapUpdateMyLocationTrackingMode(
        mode: PgMyLocationTrackingMode,
        result: @escaping FlutterResult
    ) {
        // The raw values are those of MLNUserTrackingMode.
        if let trackingMode = MLNUserTrackingMode(rawValue: UInt(mode.rawValue)) {
            setMyLocationTrackingMode(myLocationTrackingMode: trackingMode)
        }
        result(nil)
    }

    func mapMatchMapLanguageWithDeviceDefault(result: @escaping FlutterResult) {
        if let langStr = Locale.current.languageCode {
            setMapLanguage(language: langStr)
        }

        result(nil)
    }

    func mapUpdateContentInsets(
        insets: PgEdgeInsets,
        animated: Bool,
        result: @escaping FlutterResult
    ) {
        // Android completes the call when the map goes away too.
        mapView.setContentInset(
            insets.edgeInsets,
            animated: animated,
            completionHandler: completion(done: { result(nil) }, disposed: { result(nil) })
        )
    }

    /// A completion handler for MLNMapView that runs `done`, or `disposed` from
    /// `deinit` if the map goes away first: out of its window MLNMapView stops
    /// animating, and once deallocated it drops the handler. Only one runs.
    private func completion(
        done: @escaping () -> Void,
        disposed: @escaping () -> Void
    ) -> () -> Void {
        let id = nextCompletionId
        nextCompletionId += 1
        completionsAnsweredOnDispose[id] = disposed
        return { [weak self] in
            // Without self, deinit has run `disposed` already.
            guard self?.completionsAnsweredOnDispose.removeValue(forKey: id) != nil else { return }
            done()
        }
    }

    func mapSetMapLanguage(language: String, result: @escaping FlutterResult) {
        setMapLanguage(language: language)
        result(nil)
    }

    // MapLibre collects no telemetry, so there is nothing to switch, as on Android.
    func mapSetTelemetryEnabled(enabled _: Bool, result: @escaping FlutterResult) {
        result(nil)
    }

    func mapGetTelemetryEnabled(result: @escaping FlutterResult) {
        result(false)
    }

    func mapSetMaximumFps(fps: Int64, result: @escaping FlutterResult) {
        userFps = MLNMapViewPreferredFramesPerSecond(rawValue: Int(fps))
        if !pausedByDart && !isBackgroundPaused {
            mapView.preferredFramesPerSecond = userFps
        }
        result(nil)
    }

    func mapForceOnlineMode(result: @escaping FlutterResult) {
        // Force online mode by ensuring network requests are enabled
        // In MapLibre GL iOS, this is typically handled by the style and data sources
        result(nil)
    }

    func mapPause(result: @escaping FlutterResult) {
        pausedByDart = true
        mapView.preferredFramesPerSecond = MLNMapViewPreferredFramesPerSecond(rawValue: 0)
        // As on Android, a paused map stops location updates too.
        if myLocationEnabled && !manualLocationSource {
            stopLocationUpdates()
        }
        result(nil)
    }

    func mapResume(result: @escaping FlutterResult) {
        pausedByDart = false
        if !isBackgroundPaused {
            mapView.preferredFramesPerSecond = userFps
            if myLocationEnabled && !manualLocationSource {
                restartLocationPulseIfNeeded()
            }
        }
        result(nil)
    }

    func mapGetStyle(result: @escaping FlutterResult) {
        // Nil without a style.
        let json = mapView.styleJSON
        result(json.isEmpty ? nil : json)
    }

    func mapSetCustomHeaders(
        headers: [String: String],
        filter: [String],
        result: @escaping FlutterResult
    ) {
        MapLibreCustomHeaders.setCustomHeaders(headers, filter: filter)
        result(nil)
    }

    func mapGetCustomHeaders(result: @escaping FlutterResult) {
        result(MapLibreCustomHeaders.getCustomHeaders())
    }

    func mapTakeSnapshot(width: Int64?, height: Int64?, result: @escaping FlutterResult) {
        guard let styleURL = snapshotStyleURL() else {
            result(FlutterError(
                code: "STYLE_NOT_READY",
                message: "Map style is not loaded",
                details: nil
            ))
            return
        }

        let snapshotWidth = width.map { Int($0) } ?? Int(mapView.bounds.width)
        let snapshotHeight = height.map { Int($0) } ?? Int(mapView.bounds.height)

        cancelSnapshot(FlutterError(
            code: "SNAPSHOT_ERROR",
            message: "A newer takeSnapshot call cancelled this one.",
            details: nil
        ))

        let size = CGSize(width: snapshotWidth, height: snapshotHeight)
        let options = MLNMapSnapshotOptions(
            styleURL: styleURL,
            camera: mapView.camera,
            size: size
        )
        options.zoomLevel = mapView.zoomLevel

        let snapshotter = MLNMapSnapshotter(options: options)
        // Held until it finishes, or it would be deallocated. A JSON style was
        // written to a temporary file just for this snapshot.
        activeSnapshot = Snapshot(
            snapshotter: snapshotter,
            result: result,
            styleFile: styleIsJSON ? styleURL : nil
        )

        snapshotter.start { [weak self, weak snapshotter] snapshot, error in
            // A cancelled snapshotter never calls back, and cancelSnapshot
            // answered its call.
            guard let self = self, let finished = self.activeSnapshot,
                  finished.snapshotter === snapshotter
            else { return }
            self.activeSnapshot = nil
            finished.removeStyleFile()

            if let error = error {
                result(FlutterError(
                    code: "SNAPSHOT_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                return
            }
            guard let snapshot = snapshot,
                  let pngData = snapshot.image.pngData() else {
                result(FlutterError(
                    code: "SNAPSHOT_ERROR",
                    message: "Failed to generate snapshot",
                    details: nil
                ))
                return
            }
            result(FlutterStandardTypedData(bytes: pngData))
        }
    }

    /// A snapshot being taken: the snapshotter, the call it answers, and the
    /// style file written for it, if any.
    private struct Snapshot {
        let snapshotter: MLNMapSnapshotter
        let result: FlutterResult
        let styleFile: URL?

        func removeStyleFile() {
            if let styleFile = styleFile {
                try? FileManager.default.removeItem(at: styleFile)
            }
        }
    }

    /// Stops the snapshot being taken, if any, and fails its call with `error`.
    /// A cancelled snapshotter never calls back.
    private func cancelSnapshot(_ error: FlutterError) {
        guard let snapshot = activeSnapshot else { return }
        activeSnapshot = nil
        snapshot.snapshotter.cancel()
        snapshot.removeStyleFile()
        snapshot.result(error)
    }

    // MARK: Dart calls: camera

    func cameraEase(
        cameraUpdate: PgCameraUpdate,
        duration: Int64?,
        interpolation: PgCameraAnimationInterpolation?,
        result: @escaping FlutterResult
    ) {
        guard let camera = targetCamera(of: cameraUpdate, result) else {
            return
        }

        if let duration = duration.flatMap({ Double(exactly: $0) }), duration > 0 {
            let interval: TimeInterval = duration / 1000.0

            // Ease in and out when Dart names no curve.
            let timingFunction: CAMediaTimingFunction
            switch interpolation ?? .easeInOut {
            case .linear:
                timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            case .easeInOut:
                timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            case .easeOut:
                timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            case .fastOutLinearIn:
                // Material Design "fast out, linear in" cubic Bezier (0.4, 0.0, 1.0, 1.0).
                timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            }

            cameraAnimations.track(result: result) { completion in
                mapView.setCamera(camera, withDuration: interval, animationTimingFunction: timingFunction, completionHandler: completion)
            }
        } else {
            cameraAnimations.track(result: result) { completion in
                mapView.setCamera(
                    camera,
                    withDuration: MapLibreMapController.defaultCameraAnimationDuration,
                    animationTimingFunction: nil,
                    completionHandler: completion
                )
            }
        }
    }

    func cameraMove(cameraUpdate: PgCameraUpdate, result: @escaping FlutterResult) {
        guard let camera = targetCamera(of: cameraUpdate, result) else {
            return
        }
        cameraAnimations.interruptRunning()
        mapView.setCamera(camera, animated: false)
        // Always true, as on Android and web: a jump moves the camera before setCamera
        // returns, so nothing can cut it short. The Android SDK's moveCamera likewise only
        // ever calls onFinish, never onCancel.
        result(true)
    }

    func cameraAnimate(
        cameraUpdate: PgCameraUpdate,
        duration: Int64?,
        result: @escaping FlutterResult
    ) {
        guard let camera = targetCamera(of: cameraUpdate, result) else {
            return
        }

        // No edge padding here: a newLatLngBounds camera already has its
        // center shifted for the bounds padding, and padding passed to the
        // map view would stay on as camera insets after the move.
        cameraAnimations.track(result: result) { completion in
            if let duration = duration.flatMap({ TimeInterval(exactly: $0) }) {
                mapView.fly(to: camera, withDuration: duration / 1000, completionHandler: completion)
            } else {
                mapView.setCamera(
                    camera,
                    withDuration: MapLibreMapController.defaultCameraAnimationDuration,
                    animationTimingFunction: nil,
                    completionHandler: completion
                )
            }
        }
    }

    func mapSetCameraBounds(
        west: Double,
        north: Double,
        south: Double,
        east: Double,
        padding: Int64,
        result: @escaping FlutterResult
    ) {
        guard [south, west, north, east].allSatisfy(\.isFinite) else {
            result(invalidArgumentError(MethodCallError.nonFiniteCoordinates))
            return
        }
        // MapLibre aborts the app on a latitude beyond the poles.
        guard abs(south) <= 90, abs(north) <= 90 else {
            result(invalidArgumentError(MethodCallError.latitudeOutOfRange))
            return
        }
        guard let padding32 = Int32(exactly: padding) else {
            result(MethodCallError.paddingOutOfRange(padding).flutterError)
            return
        }
        let padding = CGFloat(padding32)

        let southwest = CLLocationCoordinate2D(latitude: south, longitude: west)
        let northeast = CLLocationCoordinate2D(latitude: north, longitude: east)
        let bounds = MLNCoordinateBounds(sw: southwest, ne: northeast)
        mapView.setVisibleCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: padding,
            left: padding, bottom: padding, right: padding) , animated: true)
        result(nil)
    }

    func mapQueryCameraPosition(result: @escaping FlutterResult) {
        // On-demand query: read the live camera directly. Unlike the
        // streaming paths, which go through getCamera() and honor
        // trackCameraPosition, a one-off query always returns a value.
        result(mapView.camera.toPigeon(mapView: mapView))
    }

    func mapGetVisibleRegion(result: @escaping FlutterResult) {
        result(mapView.visibleCoordinateBounds.toPigeon())
    }

    func mapToScreenLocation(latitude: Double, longitude: Double, result: @escaping FlutterResult) {
        guard latitude.isFinite, longitude.isFinite else {
            result(invalidArgumentError(MethodCallError.nonFiniteCoordinates))
            return
        }
        let latlng = CLLocationCoordinate2DMake(latitude, longitude)
        let point = mapView.convert(latlng, toPointTo: mapView)
        result(PgScreenPoint(x: Double(point.x), y: Double(point.y)))
    }

    func mapToScreenLocationBatch(
        coordinates data: FlutterStandardTypedData,
        result: @escaping FlutterResult
    ) {
        // An empty Data has no base address.
        let latLngs: [Double] = data.data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return [] }
            return Array(
                UnsafeBufferPointer(
                    start: base.assumingMemoryBound(to: Double.self),
                    count: Int(data.elementCount)
                )
            )
        }
        guard latLngs.allSatisfy(\.isFinite) else {
            result(invalidArgumentError(MethodCallError.nonFiniteCoordinates))
            return
        }
        var reply: [Double] = Array(repeating: 0.0, count: latLngs.count)
        for i in stride(from: 0, to: latLngs.count - 1, by: 2) {
            let coordinate = CLLocationCoordinate2DMake(latLngs[i], latLngs[i + 1])
            let returnVal = mapView.convert(coordinate, toPointTo: mapView)
            reply[i] = Double(returnVal.x)
            reply[i + 1] = Double(returnVal.y)
        }
        result(FlutterStandardTypedData(
            float64: Data(bytes: &reply, count: reply.count * 8)
        ))
    }

    func mapGetMetersPerPixelAtLatitude(latitude: Double, result: @escaping FlutterResult) {
        result(mapView.metersPerPoint(atLatitude: latitude))
    }

    func mapToLatLng(x: Double, y: Double, result: @escaping FlutterResult) {
        guard x.isFinite, y.isFinite else {
            result(invalidArgumentError(MethodCallError.nonFiniteScreenPoint))
            return
        }
        let screenPoint = CGPoint(x: x, y: y)
        let coordinates: CLLocationCoordinate2D = mapView.convert(
            screenPoint,
            toCoordinateFrom: mapView
        )
        result(coordinates.toPigeon())
    }

    // MARK: Dart calls: queries

    func mapQueryRenderedFeaturesAtPoint(
        x: Double,
        y: Double,
        layerIds: [String],
        filter: String?,
        result: @escaping FlutterResult
    ) {
        let styleLayerIdentifiers = queriedLayerIds(layerIds)
        answerFeatures(
            filter: filter,
            methodName: "queryRenderedFeatures",
            result: result
        ) { predicate in
            self.mapView.visibleFeatures(
                at: CGPoint(x: x, y: y),
                styleLayerIdentifiers: styleLayerIdentifiers,
                predicate: predicate
            )
        }
    }

    func mapQueryRenderedFeaturesInRect(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        layerIds: [String],
        filter: String?,
        result: @escaping FlutterResult
    ) {
        let styleLayerIdentifiers = queriedLayerIds(layerIds)
        let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        answerFeatures(
            filter: filter,
            methodName: "queryRenderedFeaturesInRect",
            result: result
        ) { predicate in
            self.mapView.visibleFeatures(
                in: rect,
                styleLayerIdentifiers: styleLayerIdentifiers,
                predicate: predicate
            )
        }
    }

    /// The layers a rendered features query looks in: `nil`, meaning all of
    /// them, for an empty list.
    private func queriedLayerIds(_ layerIds: [String]) -> Set<String>? {
        return layerIds.isEmpty ? nil : Set<String>(layerIds)
    }

    /// Answers the features `query` finds with the predicate of `filter`, the
    /// JSON text of an expression.
    ///
    /// Only an expression array filters, as on Android: no filter, the text
    /// `null` and any other JSON value query without a predicate. Text that is
    /// not JSON, or a filter MapLibre rejects, fails with INVALID_EXPRESSION.
    /// MapLibre raises an Objective-C exception for a bad filter both when it
    /// builds the predicate and when it runs the query, so both are caught.
    private func answerFeatures(
        filter: String?,
        methodName: String,
        result: FlutterResult,
        _ query: (NSPredicate?) -> [MLNFeature]
    ) {
        var json: Any?
        if let filter = filter {
            guard let data = filter.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(
                      with: data,
                      options: .fragmentsAllowed
                  )
            else {
                result(MethodCallError.invalidFilter(reason: Self.filterNotJSON).flutterError)
                return
            }
            json = parsed is [Any] ? parsed : nil
        }
        var features: [MLNFeature] = []
        let exception = MapLibreGLCatchException {
            features = query(json.map { NSPredicate(mglJSONObject: $0) })
        }
        if let exception = exception {
            result(MethodCallError.invalidFilter(
                reason: Self.filterRejection(exception)
            ).flutterError)
            return
        }
        result(featuresReply(features, methodName: methodName))
    }

    /// The reason for a filter whose text is not JSON.
    static let filterNotJSON = "Not valid JSON."

    /// Why MapLibre rejected a filter, from the exception it raised.
    static func filterRejection(_ exception: NSException) -> String {
        return (exception.reason ?? "rejected by the map")
            .replacingOccurrences(of: "Invalid filter value: ", with: "")
    }

    func mapQuerySourceFeatures(
        sourceId: String,
        sourceLayerId: String?,
        filter: String?,
        result: @escaping FlutterResult
    ) {
        guard let style = mapView.style else {
            result(MethodCallError.styleNotReady.flutterError)
            return
        }
        var sourceLayerIds = Set<String>()
        if let layerId = sourceLayerId {
            sourceLayerIds.insert(layerId)
        }
        let source = style.source(withIdentifier: sourceId)
        answerFeatures(
            filter: filter,
            methodName: "querySourceFeatures",
            result: result
        ) { predicate in
            if let vectorSource = source as? MLNVectorTileSource {
                return vectorSource.features(
                    sourceLayerIdentifiers: sourceLayerIds,
                    predicate: predicate
                )
            }
            if let shapeSource = source as? MLNShapeSource {
                return shapeSource.features(matching: predicate)
            }
            return []
        }
    }

    // MARK: Dart calls: sources

    func sourceAddGeoJson(sourceId: String, geojson: String, result: @escaping FlutterResult) {
        answer(addSourceGeojson(sourceId: sourceId, geojson: geojson), result)
    }

    func sourceSetGeoJson(sourceId: String, geojson: String, result: @escaping FlutterResult) {
        answer(setSource(sourceId: sourceId, geojson: geojson), result)
    }

    func sourceSetFeature(
        sourceId: String,
        geojsonFeature: String,
        result: @escaping FlutterResult
    ) {
        answer(setFeature(sourceId: sourceId, geojsonFeature: geojsonFeature), result)
    }

    func sourceGetClusterExpansionZoom(
        sourceId: String,
        clusterId: Int64,
        result: @escaping FlutterResult
    ) {
        let clusterId = Int(clusterId)
        switch clusterSource(sourceId: sourceId, methodName: "getClusterExpansionZoom") {
        case let .failure(error): result(error.flutterError)
        case let .success(source):
            guard hasCluster(source, clusterId: clusterId) else {
                result(clusterNotFoundError(sourceId: sourceId, clusterId: clusterId))
                return
            }
            let zoom = source.zoomLevel(forExpanding: clusterFeature(clusterId))
            // The SDK returns -1 for a cluster it cannot expand, whereas
            // Android returns 0 for the same case. Report the Android value
            // so the Dart return type can stay a plain int on both.
            result(zoom < 0 ? 0 : Int(zoom.rounded()))
        }
    }

    func sourceGetClusterChildren(
        sourceId: String,
        clusterId: Int64,
        result: @escaping FlutterResult
    ) {
        let clusterId = Int(clusterId)
        switch clusterSource(sourceId: sourceId, methodName: "getClusterChildren") {
        case let .failure(error): result(error.flutterError)
        case let .success(source):
            guard hasCluster(source, clusterId: clusterId) else {
                result(clusterNotFoundError(sourceId: sourceId, clusterId: clusterId))
                return
            }
            result(featuresReply(
                source.children(of: clusterFeature(clusterId)),
                methodName: "getClusterChildren"
            ))
        }
    }

    func sourceGetClusterLeaves(
        sourceId: String,
        clusterId: Int64,
        limit: Int64,
        offset: Int64,
        result: @escaping FlutterResult
    ) {
        let clusterId = Int(clusterId)
        let limit = Int(limit)
        let offset = Int(offset)
        switch clusterSource(sourceId: sourceId, methodName: "getClusterLeaves") {
        case let .failure(error): result(error.flutterError)
        case let .success(source):
            guard hasCluster(source, clusterId: clusterId) else {
                result(clusterNotFoundError(sourceId: sourceId, clusterId: clusterId))
                return
            }
            let leaves = source.leaves(
                of: clusterFeature(clusterId),
                offset: UInt(max(0, offset)),
                limit: UInt(max(0, limit))
            )
            result(featuresReply(leaves, methodName: "getClusterLeaves"))
        }
    }

    // MARK: Dart calls: feature state

    func sourceSetFeatureState(
        sourceId: String,
        featureId: String,
        state: [String: Any?],
        sourceLayer: String?,
        result: @escaping FlutterResult
    ) {
        let target: FeatureStateTarget
        switch featureStateTarget(sourceId: sourceId, sourceLayer: sourceLayer) {
        case let .failure(error):
            result(error.flutterError)
            return
        case let .success(found):
            target = found
        }
        // The state goes to the renderer as JSON. A non-finite number or a
        // value of a type JSON cannot carry would be raised as an exception
        // there, so it is refused up front.
        let stateObject = state.mapValues { $0 ?? NSNull() }
        guard JSONSerialization.isValidJSONObject(stateObject) else {
            result(MethodCallError.invalidArgument(
                message: "The state for feature '\(featureId)' on source '\(sourceId)' is not "
                    + "valid JSON: it holds a non-finite number, or a value of a type JSON "
                    + "cannot carry."
            ).flutterError)
            return
        }
        var applied = false
        let exception = MapLibreGLCatchException {
            switch target {
            case let .shape(source):
                applied = source.setFeatureState(featureID: featureId, state: stateObject)
            case let .vector(source, sourceLayerId):
                applied = source.setFeatureState(
                    sourceLayerID: sourceLayerId,
                    featureID: featureId,
                    state: stateObject
                )
            }
        }
        guard exception == nil, applied else {
            // The SDK setters return false instead of throwing; surfacing that
            // as an error keeps a rejected call from looking like a success.
            result(FlutterError(
                code: "FEATURE_STATE_NOT_APPLIED",
                message: "setFeatureState for feature '\(featureId)' on source '\(sourceId)' was "
                    + "rejected by the SDK. This usually means the source is no longer attached "
                    + "to the map.",
                details: nil
            ))
            return
        }
        result(nil)
    }

    func sourceRemoveFeatureState(
        sourceId: String,
        featureId: String?,
        stateKey: String?,
        sourceLayer: String?,
        result: @escaping FlutterResult
    ) {
        // A stateKey lives inside one feature's state, so without a featureId
        // there is nothing the SDK could remove it from.
        if featureId == nil, stateKey != nil {
            result(MethodCallError.invalidArgument(
                message: "removeFeatureState with a 'stateKey' also requires the 'featureId' "
                    + "that owns the key."
            ).flutterError)
            return
        }
        let target: FeatureStateTarget
        switch featureStateTarget(sourceId: sourceId, sourceLayer: sourceLayer) {
        case let .failure(error):
            result(error.flutterError)
            return
        case let .success(found):
            target = found
        }
        // Which arguments are present picks the operation, matching Android
        // and web: both drop one key, featureId alone drops that feature's
        // whole state, neither resets the whole source (or source layer).
        var applied = false
        let exception = MapLibreGLCatchException {
            switch target {
            case let .shape(source):
                if let featureId = featureId, let stateKey = stateKey {
                    applied = source.removeFeatureState(featureID: featureId, stateKey: stateKey)
                } else if let featureId = featureId {
                    applied = source.removeFeatureState(featureID: featureId)
                } else {
                    applied = source.resetFeatureStates()
                }
            case let .vector(source, sourceLayerId):
                if let featureId = featureId, let stateKey = stateKey {
                    applied = source.removeFeatureState(
                        sourceLayerID: sourceLayerId,
                        featureID: featureId,
                        stateKey: stateKey
                    )
                } else if let featureId = featureId {
                    applied = source.removeFeatureState(
                        sourceLayerID: sourceLayerId,
                        featureID: featureId
                    )
                } else {
                    applied = source.resetFeatureStates(sourceLayerID: sourceLayerId)
                }
            }
        }
        guard exception == nil, applied else {
            result(FlutterError(
                code: "FEATURE_STATE_NOT_APPLIED",
                message: "removeFeatureState on source '\(sourceId)' was rejected by the SDK. "
                    + "This usually means the source is no longer attached to the map.",
                details: nil
            ))
            return
        }
        result(nil)
    }

    func sourceGetFeatureState(
        sourceId: String,
        featureId: String,
        sourceLayer: String?,
        result: @escaping FlutterResult
    ) {
        let target: FeatureStateTarget
        switch featureStateTarget(sourceId: sourceId, sourceLayer: sourceLayer) {
        case let .failure(error):
            result(error.flutterError)
            return
        case let .success(found):
            target = found
        }
        var state: [String: Any]?
        _ = MapLibreGLCatchException {
            switch target {
            case let .shape(source):
                state = source.featureState(featureID: featureId)
            case let .vector(source, sourceLayerId):
                state = source.featureState(sourceLayerID: sourceLayerId, featureID: featureId)
            }
        }
        // Sent as a JSON string so nested values survive the channel intact,
        // like styleGetLayerProperties. No state must stay null rather than
        // become an empty map: the Dart return type is nullable and callers
        // tell "no state" from an empty state.
        guard let state = state, !state.isEmpty,
              JSONSerialization.isValidJSONObject(state),
              let json = jsonString(from: state)
        else {
            result(nil)
            return
        }
        result(json)
    }

    func mapEditGeoJsonSource(id srcId: String, data srcData: String, result: @escaping FlutterResult) {
        guard let style = self.mapView.style else {
            result(false)
            return
        }

        var ret: Bool = false
        if let data = srcData.data(using: String.Encoding.utf8) {
            let src = style.source(withIdentifier: srcId)
            if src != nil && src is MLNShapeSource {
                let geojsonSrc = src as! MLNShapeSource
                let geojsonData = try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)
                if geojsonData != nil {
                    geojsonSrc.shape = geojsonData
                    // The data setGeoJsonFeature edits.
                    addedShapesByLayer[srcId] = geojsonData
                    ret = true
                }
            }
        }

        result(ret)
    }

    func mapEditGeoJsonUrl(id srcId: String, url srcUrl: String, result: @escaping FlutterResult) {
        guard let style = self.mapView.style else {
            result(false)
            return
        }

        var ret: Bool = false
        let src = style.source(withIdentifier: srcId)
        if src != nil && src is MLNShapeSource {
            let geojsonSrc = src as! MLNShapeSource
            let geojsonUrl = SourcePropertyConverter.strictURL(srcUrl)
            if geojsonUrl != nil {
                geojsonSrc.url = geojsonUrl
                // setGeoJsonFeature cannot change data it does not hold.
                addedShapesByLayer.removeValue(forKey: srcId)
                ret = true
            }
        }

        result(ret)
    }

    // MARK: Dart calls: style

    func styleAddImage(
        name: String,
        bytes: FlutterStandardTypedData,
        sdf: Bool,
        pixelRatio: Double?,
        result: @escaping FlutterResult
    ) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        // MapLibre reads the image's pixel ratio from its scale, which is the
        // screen's unless the caller gives one.
        let scale = pixelRatio.map { CGFloat($0) } ?? UIScreen.main.scale
        guard let image = UIImage(data: bytes.data, scale: scale) else {
            result(FlutterError(
                code: "INVALID_IMAGE",
                message: "Failed to decode image bytes.",
                details: nil
            ))
            return
        }
        if sdf {
            style.setImage(image.withRenderingMode(.alwaysTemplate), forName: name)
        } else {
            style.setImage(image, forName: name)
        }
        result(nil)
    }

    func styleAddImageSource(
        imageSourceId: String,
        bytes: FlutterStandardTypedData,
        coordinates: PgLatLngQuad,
        result: @escaping FlutterResult
    ) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        if style.source(withIdentifier: imageSourceId) != nil {
            result(MethodCallError.sourceAlreadyExists(sourceId: imageSourceId).flutterError)
            return
        }
        guard coordinates.isFinite else {
            result(invalidArgumentError(MethodCallError.nonFiniteCoordinates))
            return
        }
        guard let image = UIImage(data: bytes.data) else {
            result(invalidImageError())
            return
        }

        let source = MLNImageSource(
            identifier: imageSourceId,
            coordinateQuad: coordinates.coordinateQuad,
            image: image
        )
        style.addSource(source)
        addedShapesByLayer.removeValue(forKey: imageSourceId)

        result(nil)
    }

    func styleUpdateImageSource(
        imageSourceId: String,
        bytes: FlutterStandardTypedData?,
        coordinates: PgLatLngQuad?,
        result: @escaping FlutterResult
    ) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        guard let imageSource = style.source(withIdentifier: imageSourceId) as? MLNImageSource
        else {
            result(FlutterError(
                code: "SOURCE_NOT_FOUND",
                message: "Image source \(imageSourceId) not found.",
                details: nil
            ))
            return
        }
        if let coordinates = coordinates, !coordinates.isFinite {
            result(invalidArgumentError(MethodCallError.nonFiniteCoordinates))
            return
        }
        // Read before anything changes, so a call that fails changes nothing.
        if let bytes = bytes {
            guard let image = UIImage(data: bytes.data) else {
                result(invalidImageError())
                return
            }
            imageSource.image = image
        }
        if let coordinates = coordinates {
            imageSource.coordinates = coordinates.coordinateQuad
        }
        result(nil)
    }

    func styleRemoveSource(sourceId: String, result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        guard let source = style.source(withIdentifier: sourceId) else {
            result(nil)
            return
        }
        style.removeSource(source)
        // MapLibre keeps a source a layer still uses, and what is known about
        // it stays with it.
        if style.source(withIdentifier: sourceId) == nil {
            addedShapesByLayer.removeValue(forKey: sourceId)
            sourceAttributions.removeValue(forKey: sourceId)
        }
        result(nil)
    }

    func styleAddLayer(
        imageLayerId: String,
        imageSourceId: String,
        minzoom: Double?,
        maxzoom: Double?,
        result: @escaping FlutterResult
    ) {
        answer(addRasterLayer(
            sourceId: imageSourceId,
            layerId: imageLayerId,
            belowLayerId: nil,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            properties: [:]
        ), result)
    }

    func styleAddLayerBelow(
        imageLayerId: String,
        imageSourceId: String,
        belowLayerId: String,
        minzoom: Double?,
        maxzoom: Double?,
        result: @escaping FlutterResult
    ) {
        answer(addRasterLayer(
            sourceId: imageSourceId,
            layerId: imageLayerId,
            belowLayerId: belowLayerId,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            properties: [:]
        ), result)
    }

    func styleRemoveLayer(layerId: String, result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(MethodCallError.layerNotFound(
               layerId: layerId
            ).flutterError)
            return
        }
        interactiveFeatureLayerIds.remove(layerId)
        layerChanges.removeValue(forKey: layerId)
        style.removeLayer(layer)
        result(nil)
    }

    func styleMoveLayer(layerId: String, belowLayerId: String?, result: @escaping FlutterResult) {
        guard styleIsReady, let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        // Both layers are looked up before anything moves: a missing anchor
        // found after the removal would lose the layer.
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(MethodCallError.layerNotFound(layerId: layerId).flutterError)
            return
        }
        var belowLayer: MLNStyleLayer?
        if let belowLayerId = belowLayerId {
            guard let found = style.layer(withIdentifier: belowLayerId) else {
                result(MethodCallError.layerNotFound(layerId: belowLayerId).flutterError)
                return
            }
            belowLayer = found
        }
        if belowLayerId == layerId {
            result(nil)
            return
        }
        style.removeLayer(layer)
        if let belowLayer = belowLayer {
            style.insertLayer(layer, below: belowLayer)
        } else {
            style.addLayer(layer)
        }
        result(nil)
    }

    func styleSetFilter(layerId: String, filter: String?, result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(MethodCallError.styleNotReady.flutterError)
            return
        }
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(MethodCallError.layerNotFound(
               layerId: layerId
            ).flutterError)
            return
        }
        answer(setFilter(layer, filter), result)
    }

    func styleGetFilter(layerId: String, result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(MethodCallError.styleNotReady.flutterError)
            return
        }
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(MethodCallError.layerNotFound(layerId: layerId).flutterError)
            return
        }

        // A layer without a filter answers nil, not an empty string.
        var currentLayerFilter: String?
        if let vectorLayer = layer as? MLNVectorStyleLayer {
            if let filter = layerFilter(of: vectorLayer, loaded: loadedStyleLayer(layerId)),
               let data = try? JSONSerialization.data(withJSONObject: filter, options: .fragmentsAllowed)
            {
                currentLayerFilter = String(data: data, encoding: .utf8)
            }
        } else {
            result(MethodCallError.invalidLayerType(
                details: "Layer '\(layer.identifier)' does not support filtering."
            ).flutterError)
            return;
        }

        result(currentLayerFilter)
    }

    func styleAddSource(sourceId: String, properties: [String: Any], result: @escaping FlutterResult) {
        answer(addSource(sourceId: sourceId, properties: properties), result)
    }

    func styleSetLight(light lightProperties: [String: Any], result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(MethodCallError.styleNotReady.flutterError)
            return
        }

        // Every LightProperties field is dynamic, so anything can arrive here.
        // MapLibre Native takes constants only: a value that is not one is
        // rejected, as on Android, rather than skipped. All fields are
        // checked before any is applied, so a rejected call changes nothing.
        func invalidLight(_ field: String, _ expected: String) -> FlutterError {
            return FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Invalid '\(field)' in 'light'. Expected \(expected). MapLibre "
                    + "Native takes constant light values only, not expressions.",
                details: nil
            )
        }
        // A Dart bool arrives as an NSNumber too; reject it like Android.
        func lightNumber(_ value: Any) -> NSNumber? {
            guard let number = value as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID()
            else { return nil }
            return number
        }
        let anchorValue = lightProperties["anchor"]
        let anchor = anchorValue as? String
        if anchorValue != nil, anchor == nil {
            result(invalidLight("anchor", "a String"))
            return
        }
        let positionValue = lightProperties["position"]
        var position: [Double]?
        if let positionValue = positionValue {
            let elements = positionValue as? [Any] ?? []
            let numbers = elements.compactMap(lightNumber)
            guard elements.count == 3, numbers.count == 3 else {
                result(invalidLight("position", "three numbers, [radial, azimuthal, polar]"))
                return
            }
            position = numbers.map { $0.doubleValue }
        }
        let colorValue = lightProperties["color"]
        let color = colorValue as? String
        if colorValue != nil, color == nil {
            result(invalidLight("color", "a String"))
            return
        }
        let intensityValue = lightProperties["intensity"]
        let intensity = intensityValue.flatMap(lightNumber)?.doubleValue
        if intensityValue != nil, intensity == nil {
            result(invalidLight("intensity", "a number"))
            return
        }

        let light = style.light
        if let anchor = anchor {
            light.anchor = NSExpression(forConstantValue: anchor)
        }
        if let position = position {
            light.position = NSExpression(forConstantValue: NSValue(
                mlnSphericalPosition: MLNSphericalPositionMake(
                    CGFloat(position[0]),
                    position[1],
                    position[2]
                )
            ))
        }
        if let color = color {
            if let parsed = UIColor(hexString: color) {
                light.color = NSExpression(forConstantValue: parsed)
            } else {
                // UIColor(hexString:) only reads hex colors, so "red" or
                // "rgba(...)" are handed to the renderer as
                // LayerPropertyConverter does for layer colors, rather than
                // dropped. Without the fallback argument MLN raises an
                // uncaught NSInternalInconsistencyException at render time
                // when the input string can't be cast.
                light.color = NSExpression(mglJSONObject: ["to-color", color, "#000000"])
            }
        }
        if let intensity = intensity {
            light.intensity = NSExpression(forConstantValue: intensity)
        }
        style.light = light

        result(nil)
    }

    func styleGetLayerIds(result: @escaping FlutterResult) {
        // An empty list would read as a style without layers.
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }

        result(style.layers.map { $0.identifier })
    }

    func styleGetSourceIds(result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }

        result(style.sources.map { $0.identifier })
    }

    func styleGetLayerProperties(layerId: String, result: @escaping FlutterResult) {
        // Nil would read as "no such layer".
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        // Nil when there is no such layer.
        result(style.layer(withIdentifier: layerId).flatMap(layerProperties).flatMap(jsonString))
    }

    /// The style-spec entry of `layer`, read from the layer as on Android, so
    /// it follows every change since the style loaded. A paint or layout
    /// property is there once it is set, and `visibility` always is. What
    /// MapLibre cannot read back stays as the style wrote it.
    private func layerProperties(_ layer: MLNStyleLayer) -> [String: Any]? {
        let changes = layerChanges[layer.identifier]
        let loaded = changes?.isAdded == true ? nil : loadedStyleLayer(layer.identifier)
        guard let type = Self.layerType(of: layer),
              let readable = LayerPropertyConverter.readableProperties(of: layer)
        else {
            // Not a style-spec layer type, such as a custom layer.
            return loaded
        }
        var properties: [String: Any] = ["id": layer.identifier, "type": type]
        if let metadata = loaded?["metadata"] {
            properties["metadata"] = metadata
        }
        if let source = (layer as? MLNForegroundStyleLayer)?.sourceIdentifier, !source.isEmpty {
            properties["source"] = source
        }
        if let vectorLayer = layer as? MLNVectorStyleLayer {
            if let sourceLayer = vectorLayer.sourceLayerIdentifier, !sourceLayer.isEmpty {
                properties["source-layer"] = sourceLayer
            }
            if let filter = layerFilter(of: vectorLayer, loaded: loaded) {
                properties["filter"] = filter
            }
        }
        // Like Android, the spec defaults (0 and 24) are left out. Going
        // through the shortest Float text keeps 0.1 from reading back as
        // 0.10000000149011612.
        if layer.minimumZoomLevel > 0 {
            properties["minzoom"] = Double(String(layer.minimumZoomLevel))
        }
        if layer.maximumZoomLevel < 24 {
            properties["maxzoom"] = Double(String(layer.maximumZoomLevel))
        }
        let names = changes?.propertyNames ?? Self.propertyNames(in: loaded)
        func section(_ key: String, _ readableNames: [String]) -> [String: Any] {
            let style = loaded?[key] as? [String: Any] ?? [:]
            var json = style.filter { !readableNames.contains($0.key) }
            for name in readableNames where names.contains(name) {
                json[name] = propertyJSON(name, of: layer) ?? style[name]
            }
            return json
        }
        var layout = section("layout", readable.layout)
        layout["visibility"] = layer.isVisible ? "visible" : "none"
        properties["paint"] = section("paint", readable.paint)
        properties["layout"] = layout
        return properties
    }

    /// The style-spec JSON of the property `name` of `layer`, or nil when
    /// MapLibre cannot give it.
    private func propertyJSON(_ name: String, of layer: MLNStyleLayer) -> Any? {
        var json: Any?
        let exception = MapLibreGLCatchException {
            json = LayerPropertyConverter.propertyValue(name, of: layer)
                .flatMap(LayerPropertyConverter.styleJSON)
        }
        guard exception == nil, let value = json, JSONSerialization.isValidJSONObject([value])
        else { return nil }
        return value
    }

    /// The filter of `layer` as it was set, or as the style wrote it, or nil
    /// for none. `loaded` is the style's entry of the layer.
    private func layerFilter(
        of layer: MLNVectorStyleLayer,
        loaded: @autoclosure () -> [String: Any]?
    ) -> Any? {
        if let filter = layerChanges[layer.identifier]?.filter {
            return filter is NSNull ? nil : filter
        }
        if let loaded = loaded() {
            return loaded["filter"]
        }
        // A layer added outside this plugin: only MapLibre knows its filter.
        var filter: Any?
        _ = MapLibreGLCatchException {
            filter = layer.predicate?.mgl_jsonExpressionObject
        }
        guard let json = filter, JSONSerialization.isValidJSONObject([json]) else { return nil }
        return json
    }

    func styleGetSourceProperties(sourceId: String, result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        guard let source = style.source(withIdentifier: sourceId) else {
            result(nil)
            return
        }
        if let imageSource = source as? MLNImageSource {
            result(jsonString(from: Self.imageSourceProperties(imageSource)))
            return
        }
        // As on Android, a source that came with the style reads as loaded:
        // only the style holds all of its properties (data, tiles, ...).
        let sources = currentStyleObject()?["sources"] as? [String: Any]
        if let loaded = sources?[sourceId] as? [String: Any] {
            result(jsonString(from: loaded))
            return
        }
        result(runtimeSourceProperties(source).flatMap(jsonString))
    }

    /// The style-spec entry of `source`, added since the style loaded. As on
    /// Android, MapLibre keeps little of it: the type, the url (`data` for
    /// GeoJSON loaded from one) and the attribution. Nil for a source the
    /// style spec has no type for.
    private func runtimeSourceProperties(_ source: MLNSource) -> [String: Any]? {
        guard let type = Self.styleSourceType(source) else { return nil }
        var properties: [String: Any] = ["type": type]
        if let url = (source as? MLNShapeSource)?.url {
            properties["data"] = url.absoluteString
        }
        if let url = (source as? MLNTileSource)?.configurationURL {
            properties["url"] = url.absoluteString
        }
        if let attribution = sourceAttributions[source.identifier], !attribution.isEmpty {
            properties["attribution"] = attribution
        }
        return properties
    }

    /// The style-spec entry of `source`: its type, four [lng, lat] corners from
    /// the top left clockwise, and the url when the image comes from one.
    static func imageSourceProperties(_ source: MLNImageSource) -> [String: Any] {
        let quad = source.coordinates
        var properties: [String: Any] = [
            "type": "image",
            "coordinates": [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft].map {
                [$0.longitude, $0.latitude]
            },
        ]
        if let url = source.url {
            properties["url"] = url.absoluteString
        }
        return properties
    }

    func styleSetStyle(style: String, result: @escaping FlutterResult) {
        setStyleString(styleString: style)
        result(nil)
    }

    // MARK: Dart calls: layers

    func symbolLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addSymbolLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            sourceLayerIdentifier: sourceLayer,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            filter: filter,
            enableInteraction: enableInteraction,
            properties: properties
        ), result)
    }

    func lineLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addLineLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            sourceLayerIdentifier: sourceLayer,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            filter: filter,
            enableInteraction: enableInteraction,
            properties: properties
        ), result)
    }

    func circleLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addCircleLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            sourceLayerIdentifier: sourceLayer,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            filter: filter,
            enableInteraction: enableInteraction,
            properties: properties
        ), result)
    }

    func fillLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addFillLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            sourceLayerIdentifier: sourceLayer,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            filter: filter,
            enableInteraction: enableInteraction,
            properties: properties
        ), result)
    }

    func fillExtrusionLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addFillExtrusionLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            sourceLayerIdentifier: sourceLayer,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            filter: filter,
            enableInteraction: enableInteraction,
            properties: properties
        ), result)
    }

    func rasterLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addRasterLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            properties: properties
        ), result)
    }

    func hillshadeLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addHillshadeLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            properties: properties
        ), result)
    }

    func colorReliefLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addColorReliefLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            properties: properties
        ), result)
    }

    func backgroundLayerAdd(
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addBackgroundLayer(
            layerId: layerId,
            belowLayerId: belowLayerId,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            properties: properties
        ), result)
    }

    func heatmapLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        properties: [String: Any],
        result: @escaping FlutterResult
    ) {
        answer(addHeatmapLayer(
            sourceId: sourceId,
            layerId: layerId,
            belowLayerId: belowLayerId,
            sourceLayerIdentifier: sourceLayer,
            minimumZoomLevel: minzoom,
            maximumZoomLevel: maxzoom,
            filter: filter,
            properties: properties
        ), result)
    }

    func layerSetProperties(layerId: String, properties: [String: Any], result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(MethodCallError.layerNotFound(layerId: layerId).flutterError)
            return
        }
        guard let check = propertyCheckLayer(like: layer) else {
            result(FlutterError(
                code: "UNSUPPORTED_LAYER_TYPE",
                message: "Layer type not supported",
                details: nil
            ))
            return
        }
        // Checked on a layer outside the style first, so a failed call
        // changes nothing.
        if let error = applyLayerProperties(
            properties,
            to: layer,
            layerId: layerId,
            checkingOn: check
        ) {
            result(error.flutterError)
            return
        }
        result(nil)
    }

    func layerSetVisibility(layerId: String, visible: Bool, result: @escaping FlutterResult) {
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(MethodCallError.layerNotFound(
               layerId: layerId
            ).flutterError)
            return
        }
        layer.isVisible = visible
        result(nil)
    }

    func layerSetVisibilityBatch(layerIds: [String], visible: Bool, result: @escaping FlutterResult) {
        // Unknown ids are skipped and returned, as on Android and web.
        // An empty list answers an empty list, even without a style.
        if layerIds.isEmpty {
            result([String]())
            return
        }
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        var missingLayerIds: [String] = []
        for layerId in layerIds {
            guard let layer = style.layer(withIdentifier: layerId) else {
                if !missingLayerIds.contains(layerId) {
                    missingLayerIds.append(layerId)
                }
                continue
            }
            layer.isVisible = visible
        }
        result(missingLayerIds)
    }

    func layerSetZoomRange(
        layerId: String,
        minzoom: Double,
        maxzoom: Double,
        result: @escaping FlutterResult
    ) {
        // Checked here because MapLibre takes any range, and Android and
        // web reject the same values.
        guard minzoom >= 0, maxzoom <= 24, minzoom <= maxzoom else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Invalid zoom range [\(minzoom), \(maxzoom)]: both must be within 0 and 24, "
                    + "with minzoom not above maxzoom.",
                details: nil
            ))
            return
        }
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(MethodCallError.layerNotFound(layerId: layerId).flutterError)
            return
        }
        layer.minimumZoomLevel = Float(minzoom)
        layer.maximumZoomLevel = Float(maxzoom)
        result(nil)
    }

    func layerGetVisibility(layerId: String, result: @escaping FlutterResult) {
        // Without a style there is no layer to look up, and null would read
        // as "no such layer", so report it as Android does.
        guard let style = mapView.style else {
            result(styleNotReadyError())
            return
        }
        // Documented contract: null tells the caller there is no such layer.
        guard let layer = style.layer(withIdentifier: layerId) else {
            result(nil)
            return
        }
        result(layer.isVisible)
    }

    func mapSetLayerFilter(id layerId: String, filter layerFilter: String, result: @escaping FlutterResult) {
        // False without a style or such a layer, for a layer that takes no
        // filter and for a filter MapLibre rejects.
        guard let layer = mapView.style?.layer(withIdentifier: layerId) else {
            result(false)
            return
        }
        switch setFilter(layer, layerFilter) {
        case .success: result(true)
        case .failure: result(false)
        }
    }

    // MARK: Dart calls: location component

    func locationComponentSetTrackingCameraOptions(
        tilt: Double,
        duration: Int64?,
        result: @escaping FlutterResult
    ) {
        // Same precondition Android checks, and the same error code: without the
        // user-location component there is nothing to track, and telling the app
        // to enable a tracking mode would not be the fix.
        guard mapView.showsUserLocation else {
            result(
                FlutterError(
                    code: "LOCATION_COMPONENT_NOT_READY",
                    message: "The location component is not ready. Ensure the map was "
                        + "created with myLocationEnabled: true.",
                    details: nil
                )
            )
            return
        }
        guard mapView.userTrackingMode != .none else {
            result(
                FlutterError(
                    code: "TRACKING_NOT_ACTIVE",
                    message: "A tracking mode other than MyLocationTrackingMode.none "
                        + "must be active before a tracking camera option can be applied.",
                    details: nil
                )
            )
            return
        }
        // The iOS SDK has no tracking-aware camera call, so the pitch goes through
        // the ordinary camera. That is safe on the pinned SDK:
        // `setCamera(_:withDuration:...)` leaves `userTrackingMode` alone, and the
        // follow paths (`didUpdateLocationIncrementallyDuration:`,
        // `didUpdateLocationSignificantlyAnimated:`) never write the pitch, so the
        // camera keeps following the user tilted. Nothing is restored afterwards on
        // purpose: a mode change arriving during the animation is the user panning,
        // and putting the mode back would fight the gesture and hide the dismissal.
        let camera = mapView.camera
        camera.pitch = CGFloat(tilt)
        let durationMs = duration.map { Double($0) }
        mapView.setCamera(
            camera,
            withDuration: (durationMs ?? Double(MapLibreMapController.defaultTrackingTiltDurationMs)) / 1000.0,
            animationTimingFunction: nil,
            completionHandler: completion(
                done: { [weak self] in
                    // The completion runs both when the animation finishes and when it is
                    // interrupted, with no flag telling the two apart, so the pitch that
                    // actually landed decides the answer. Android reports a cancelled tilt
                    // as false the same way, and the Dart API promises that.
                    guard let self = self else {
                        result(false)
                        return
                    }
                    result(abs(self.mapView.camera.pitch - CGFloat(tilt)) < 0.5)
                },
                // A tilt the map never finished, as on Android.
                disposed: { result(false) }
            )
        )
    }

    func locationComponentSetManualLocation(
        update: PgManualLocationUpdate,
        result: @escaping FlutterResult
    ) {
        guard manualLocationSource else {
            result(
                FlutterError(
                    code: "MANUAL_LOCATION_SOURCE_DISABLED",
                    message: "Manual locations require locationSource: ManualLocationSource().",
                    details: nil
                )
            )
            return
        }
        // Negative accuracies/course/speed mark a value as invalid in CLLocation.
        let location = CLLocation(
            coordinate: update.position.coordinate,
            altitude: update.altitude ?? 0,
            horizontalAccuracy: update.horizontalAccuracy ?? -1,
            verticalAccuracy: update.verticalAccuracy ?? -1,
            course: update.bearing ?? -1,
            speed: update.speed ?? -1,
            timestamp: Date(timeIntervalSince1970: Double(update.timestamp) / 1000.0)
        )
        // Kept for when myLocationEnabled turns on. While it is off the puck is
        // hidden and no location reaches the map, so no update is sent.
        lastManualLocation = location
        if mapView.showsUserLocation {
            // The map view's delegate then sends mapOnUserLocationUpdated.
            manualLocationManager.push(location)
        }
        result(nil)
    }

    func locationComponentGetLastLocation(result: @escaping FlutterResult) {
        if let loc = mapView.userLocation?.location?.coordinate {
            result(loc.toPigeon())
        } else {
            result(
                FlutterError(
                    code: "LOCATION_UNAVAILABLE",
                    message: "User location is not available",
                    details: nil
                )
            )
        }
    }

    private func updateMyLocationEnabled() {
        if myLocationEnabled {
            restartLocationPulseIfNeeded()
        } else {
            stopLocationUpdates()
            mapView.showsUserLocation = false
        }
    }

    /// Stops the pulse timers and Core Location, keeping the user-location annotation.
    private func stopLocationUpdates() {
        locationPulseTimer?.invalidate()
        locationPulseTimer = nil
        locationPulseWindowTimer?.invalidate()
        locationPulseWindowTimer = nil
        setLocationUpdatesActive(false)
    }

    /// Start or stop Core Location updates without toggling the user-location annotation.
    private func setLocationUpdatesActive(_ active: Bool) {
        guard let locationManager = mapView.locationManager else { return }
        if active {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
        }
    }

    /// Applies `initialCameraPosition` once, as soon as the view has a size.
    /// The altitude is computed for the real size, so zoom, bearing and tilt
    /// all land; on a 0x0 view the same call would be silently dropped.
    private func applyInitialCameraIfNeeded() {
        guard let initialCameraPosition = pendingInitialCamera,
              !mapView.frame.size.equalTo(.zero) else { return }
        pendingInitialCamera = nil
        mapView.setCamera(
            MLNMapCamera.fromPigeon(initialCameraPosition, mapView: mapView),
            animated: false
        )
    }

    private func getCamera() -> MLNMapCamera? {
        return trackCameraPosition ? mapView.camera : nil
    }

    private func setMapLanguage(language: String) {
        self.mapView.setMapLanguage(language)
    }

    // The current map style parsed as a JSON dictionary (style-spec shaped),
    // or nil if it cannot be read/parsed. Used to read layer/source properties
    // by id without enumerating every typed property.
    private func currentStyleObject() -> [String: Any]? {
        guard let data = mapView.styleJSON.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // Serializes a style sub-object (a layer or source entry) back to a JSON
    // string for the Dart side, which decodes it into a Map.
    private func jsonString(from object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Half the side, in points, of the square around a touch where taps and drags look for a
    /// feature. Android uses the same value in dp.
    private static let featureHitTolerance: CGFloat = 8

    /*
     *  Return the interactive feature nearest to the point, looking up to featureHitTolerance
     *  around it. Nearness is measured to what the feature draws: the square around the point
     *  grows one point at a time and the first feature it touches wins. When several features
     *  are reached at the same distance, the top-most layer wins. With draggableOnly, features
     *  that cannot be dragged are left out, so they never hide one that can. A touch inside a
     *  polygon hole reaches the polygon only at its ring edges, see PolygonHitTest.
     */
    private func firstFeatureOnLayers(
        at: CGPoint,
        draggableOnly: Bool = false
    ) -> (feature: MLNFeature?, layerId: String?) {
        guard let style = mapView.style else { 
            NSLog("MapLibreMapController - Map style is nil")
            return (nil, nil)
        }

        guard styleIsReady else {
            NSLog("MapLibreMapController - Map style is not ready yet")
            return (nil, nil)
        }

        // get layers in order (interactiveFeatureLayerIds is unordered)
        let clickableLayers = style.layers.filter { layer in
            interactiveFeatureLayerIds.contains(layer.identifier)
        }

        let holes = PolygonHitTest(
            touch: mapView.convert(at, toCoordinateFrom: mapView),
            zoom: mapView.zoomLevel
        )
        func hits(within radius: CGFloat, _ layerId: String) -> [MLNFeature] {
            let rect = CGRect(x: at.x - radius, y: at.y - radius, width: radius * 2, height: radius * 2)
            let features = mapView.visibleFeatures(in: rect, styleLayerIdentifiers: [layerId])
            return features.filter { feature in
                if draggableOnly, (feature.attribute(forKey: "draggable") as? Bool) != true {
                    return false
                }
                return holes.keeps(feature, radius: Double(radius))
            }
        }
        let tolerance = MapLibreMapController.featureHitTolerance

        // One query over the whole area keeps only the layers with something in reach.
        var candidateLayers: [String] = []
        var onlyHit: (feature: MLNFeature?, layerId: String?) = (nil, nil)
        var hitCount = 0
        for layer in clickableLayers.reversed() {
            let features = hits(within: tolerance, layer.identifier)
            if let feature = features.first {
                candidateLayers.append(layer.identifier)
                hitCount += features.count
                onlyHit = (feature, layer.identifier)
            }
        }
        if hitCount <= 1 {
            return onlyHit
        }

        for radius in stride(from: CGFloat(1), through: tolerance, by: 1) {
            for layerId in candidateLayers {
                let features = hits(within: radius, layerId)
                if let feature = features.first {
                    return (feature, layerId)
                }
            }
        }
        return (nil, nil)
    }

    /*
     *  UITapGestureRecognizer
     *  On tap send mapOnMapClick.
     */
    @IBAction func handleMapTap(sender: UITapGestureRecognizer) {
        // Get the CGPoint where the user tapped.
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

        let screenPoint = PgScreenPoint(x: Double(point.x), y: Double(point.y))
        let latLng = coordinate.toPigeon()

        let result = firstFeatureOnLayers(at: point)
        if let feature = result.feature {
            flutterApi?.featureOnTap(tap: PgFeatureTap(
                id: feature.identifier,
                point: screenPoint,
                latLng: latLng,
                layerId: result.layerId
            )) { _ in }
            // Send mapOnMapClick only if featureTapsTriggersMapClick is true
            if featureTapsTriggersMapClick {
                flutterApi?.mapOnMapClick(point: screenPoint, latLng: latLng) { _ in }
            }
        } else {
            // Always send mapOnMapClick when no feature is tapped
            flutterApi?.mapOnMapClick(point: screenPoint, latLng: latLng) { _ in }
        }
    }

    fileprivate func invokeFeatureDrag(
        _ point: CGPoint,
        _ coordinate: CLLocationCoordinate2D,
        _ eventType: String
    ) {
        if let feature = dragFeature,
           let id = feature.identifier,
           let previous = previousDragCoordinate,
           let origin = originDragCoordinate
        {
            flutterApi?.featureOnDrag(drag: PgFeatureDrag(
                id: id,
                point: PgScreenPoint(x: Double(point.x), y: Double(point.y)),
                origin: origin.toPigeon(),
                current: coordinate.toPigeon(),
                delta: PgLatLng(
                    latitude: coordinate.latitude - previous.latitude,
                    longitude: coordinate.longitude - previous.longitude
                ),
                eventType: eventType
            )) { _ in }
        }
    }

    private func endFeatureDrag(
        _ point: CGPoint,
        _ coordinate: CLLocationCoordinate2D
    ) {
        mapView.allowsScrolling = scrollingEnabled
        invokeFeatureDrag(point, coordinate, "end")
        dragFeature = nil
        originDragCoordinate = nil
        previousDragCoordinate = nil
    }

    @IBAction func handleMapPan(sender: UIPanGestureRecognizer) {
        let began = sender.state == UIGestureRecognizer.State.began
        // A drag the system cancels (a call, Control Center, the app leaving)
        // ends too: otherwise the feature stays grabbed, scrolling stays off,
        // and the next pan anywhere drags it. Only this controller's own pan:
        // the map's, which this method also serves, is cancelled on purpose
        // when a drag turns scrolling off.
        let interrupted = sender === featureDragPan && [
            UIGestureRecognizer.State.cancelled,
            UIGestureRecognizer.State.failed,
        ].contains(sender.state)
        let end = sender.state == UIGestureRecognizer.State.ended || interrupted
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

        if dragFeature == nil, began, sender.numberOfTouches == 1 {
            // Hit test where the finger came down, like Android: the pan begins
            // only after the finger has moved, which can miss a small feature.
            let result = firstFeatureOnLayers(at: featureDragTouchDown ?? point, draggableOnly: true)
            if let feature = result.feature,
            let draggable = feature.attribute(forKey: "draggable") as? Bool,
            draggable {
                sender.state = UIGestureRecognizer.State.began
                dragFeature = feature
                originDragCoordinate = coordinate
                previousDragCoordinate = coordinate
                mapView.allowsScrolling = false
                let eventType = "start"
                invokeFeatureDrag(point, coordinate, eventType)
                for gestureRecognizer in mapView.gestureRecognizers! {
                    if let _ = gestureRecognizer as? UIPanGestureRecognizer {
                        gestureRecognizer.addTarget(self, action: #selector(handleMapPan))
                        break
                    }
                }
            }
        }
        // A second finger ends the drag, like on Android: one end where the
        // single finger last was, then the map takes the gesture (pinch).
        // Cancelling the drag pan sends one more call with dragFeature nil,
        // so no drag or second end follows.
        if !end, dragFeature != nil, sender.numberOfTouches > 1,
           let previous = previousDragCoordinate
        {
            endFeatureDrag(mapView.convert(previous, toPointTo: mapView), previous)
            featureDragPan?.isEnabled = false
            featureDragPan?.isEnabled = true
            return
        }

        if end, dragFeature != nil {
            endFeatureDrag(point, coordinate)
        }

        if !began, !end, dragFeature != nil {
            let eventType = "drag"
            invokeFeatureDrag(point, coordinate, eventType)
            previousDragCoordinate = coordinate
        }
    }

    /*
     *  UILongPressGestureRecognizer
     *  After a long press send mapOnMapLongClick.
     */
    @IBAction func handleMapLongPress(sender: UILongPressGestureRecognizer) {
        // Fire when the long press starts
        if sender.state == .began {
            // Get the CGPoint where the user tapped.
            let point = sender.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            flutterApi?.mapOnMapLongClick(
                point: PgScreenPoint(x: Double(point.x), y: Double(point.y)),
                latLng: coordinate.toPigeon()
            ) { _ in }
        }
    }

    /*
     *  MLNMapViewDelegate
     */
    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        isMapReady = true
        style.performsPlacementTransitions = symbolPlacementTransitionsEnabled
        updateMyLocationEnabled()

        // Before mapWaitForMap replies and onStyleLoaded fires, so Dart
        // sees initialCameraPosition there.
        applyInitialCameraIfNeeded()

        addedShapesByLayer.removeAll()
        interactiveFeatureLayerIds.removeAll()
        layerChanges.removeAll()
        sourceAttributions.removeAll()

        // A parked mapWaitForMap is answered once: a later style load, after
        // a setStyle, must not reply to the same message again.
        let waitingResults = mapReadyResults
        mapReadyResults.removeAll()
        waitingResults.forEach { $0(nil) }

        // On first launch we only fire onStyleLoaded if mapWaitForMap has already been called
        if !isFirstStyleLoad || !waitingResults.isEmpty {
            isFirstStyleLoad = false

            onStyleLoadedCalled = true
            // Defer the callback to the next run loop iteration to avoid race conditions
            // where the map's internal state is not fully ready for operations like camera animations
            let api = flutterApi
            DispatchQueue.main.async {
                api?.mapOnStyleLoaded { _ in }
            }
        }
    }

    // An image the style does not have may name a Flutter asset.
    func mapView(_: MLNMapView, didFailToLoadImage name: String) -> UIImage? {
        return AssetIcons.load(
            mainPath: registrar.lookupKey(forAsset: name),
            screenScale: UIScreen.main.scale
        )
    }

    func mapView(
        styleForDefaultUserLocationAnnotationView mapView: MLNMapView
    ) -> MLNUserLocationAnnotationViewStyle {
        return locationPuckStyle.annotationViewStyle(defaultTint: mapView.tintColor)
    }

    /// Recolors the default puck view from `locationPuckStyle`.
    ///
    /// The view takes its accuracy circle color from its tint, and builds its
    /// layers from the map's tint whenever it redraws: when it first appears,
    /// and when course tracking starts or stops. So this runs after each of
    /// those, on the next main-queue turn, once the SDK has drawn the view.
    private func applyLocationPuckTint() {
        guard locationPuckTinted || !locationPuckStyle.isDefault else { return }
        guard let userLocation = mapView.userLocation,
              let view = mapView.view(for: userLocation) as? MLNUserLocationAnnotationView
        else { return }
        locationPuckTinted = true
        view.tintColor = locationPuckStyle.viewTintColor(
            defaultTint: mapView.tintColor,
            followingCourse: mapView.userTrackingMode == .followWithCourse
        )
    }

    private func scheduleLocationPuckTint() {
        guard locationPuckTinted || !locationPuckStyle.isDefault else { return }
        DispatchQueue.main.async { [weak self] in
            self?.applyLocationPuckTint()
        }
    }

    func mapView(_: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
        scheduleLocationPuckTint()
        if let userLocation = userLocation, let location = userLocation.location {
            flutterApi?.mapOnUserLocationUpdated(
                userLocation: location.toPigeon(),
                heading: userLocation.heading?.toPigeon()
            ) { _ in }
        }
    }

    func mapView(_: MLNMapView, didChange mode: MLNUserTrackingMode, animated _: Bool) {
        scheduleLocationPuckTint()
        // The raw values are those of MLNUserTrackingMode.
        if let trackingMode = PgMyLocationTrackingMode(rawValue: Int(mode.rawValue)) {
            flutterApi?.mapOnCameraTrackingChanged(mode: trackingMode) { _ in }
        }
        if mode == .none {
            flutterApi?.mapOnCameraTrackingDismissed { _ in }
        }
    }

    /// The style and the source of a layer add, or the error it fails with, in
    /// the order Android checks them. MapLibre raises an Objective-C
    /// exception, which Swift cannot catch, for a layer that cannot draw its
    /// source, and adds a layer on a vector source without a source layer
    /// that draws nothing.
    private func validateBeforeLayerAdd(
        sourceId: String,
        layerId: String,
        layerType: String,
        sourceLayer: String? = nil
    ) -> Result<(MLNStyle, MLNSource), MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        guard style.layer(withIdentifier: layerId) == nil else {
            return .failure(.layerAlreadyExists(layerId: layerId))
        }
        guard let source = style.source(withIdentifier: sourceId) else {
            return .failure(.sourceNotFound(sourceId: sourceId))
        }
        if let sourceType = Self.styleSourceType(source),
           !Self.canDraw(layerType: layerType, sourceType: sourceType)
        {
            return .failure(.unsupportedSourceType(
                message: "Layer '\(layerId)' of type '\(layerType)' cannot use source "
                    + "'\(sourceId)' of type '\(sourceType)'."
            ))
        }
        if source is MLNVectorTileSource, sourceLayer?.isEmpty ?? true {
            return .failure(.sourceLayerRequired(layerId: layerId, sourceId: sourceId))
        }
        return .success((style, source))
    }

    /// The style-spec type of `source`, or nil for a source the style spec has
    /// no type for.
    static func styleSourceType(_ source: MLNSource) -> String? {
        switch source {
        case is MLNShapeSource: return "geojson"
        case is MLNVectorTileSource: return "vector"
        // A raster-dem source is a raster tile source too.
        case is MLNRasterDEMSource: return "raster-dem"
        case is MLNRasterTileSource: return "raster"
        case is MLNImageSource: return "image"
        default: return nil
        }
    }

    /// Whether a layer of `layerType` can draw a source of `sourceType`: a
    /// layer draws the kind of tile its source makes.
    static func canDraw(layerType: String, sourceType: String) -> Bool {
        switch layerType {
        case "fill", "line", "symbol", "circle", "heatmap", "fill-extrusion":
            return sourceType == "geojson" || sourceType == "vector"
        case "raster":
            return sourceType == "raster" || sourceType == "image"
        case "hillshade", "color-relief":
            return sourceType == "raster-dem"
        default:
            return true
        }
    }

    /// Adds `layer` to `style` below `belowLayerId`, or on top without such a
    /// layer, as on Android and web. An Objective-C exception MapLibre raises
    /// fails the call with INVALID_ARGUMENT.
    private func insert(
        _ layer: MLNStyleLayer,
        into style: MLNStyle,
        below belowLayerId: String?
    ) -> Result<Void, MethodCallError> {
        let exception = MapLibreGLCatchException {
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
        }
        if let exception = exception {
            return .failure(.invalidArgument(
                message: "Layer '\(layer.identifier)' cannot be added: "
                    + (exception.reason ?? exception.name.rawValue)
            ))
        }
        return .success(())
    }

    /// Sets `properties` on `layer` in name order and returns the first value
    /// MapLibre rejects, also logged. Each value is converted once. With a
    /// `check` layer, of the type of `layer` and outside the style, every
    /// value is tried there first, so a rejected call changes nothing.
    /// Constants are checked against their kind first: MapLibre on iOS reads a
    /// constant of the wrong kind as something else.
    private func applyLayerProperties(
        _ properties: [String: Any],
        to layer: MLNStyleLayer,
        layerId: String,
        checkingOn check: MLNStyleLayer? = nil
    ) -> MethodCallError? {
        guard let layerType = Self.layerType(of: layer) else { return nil }
        var converted: [(name: String, value: Any, expression: NSExpression?)] = []
        for name in properties.keys.sorted() where Self.isProperty(name, of: layerType) {
            let value = properties[name] ?? NSNull()
            let isNull = value is NSNull
            var reason: String?
            if !isNull, !Self.isExpression(value) {
                reason = LayerPropertyConverter.constantError(propertyName: name, value: value)
            }
            var expression: NSExpression?
            if reason == nil {
                let exception = MapLibreGLCatchException {
                    expression = LayerPropertyConverter.propertyExpression(name, value: value)
                    // Null resets the property, which MapLibre always takes.
                    if let check = check, let expression = expression {
                        LayerPropertyConverter.setProperty(
                            name,
                            value: value,
                            expression: expression,
                            on: check
                        )
                    }
                }
                reason = exception.map { $0.reason ?? $0.name.rawValue }
            }
            if let reason = reason {
                return rejectedProperty(layerId: layerId, name, value, reason)
            }
            // A value the converter cannot read leaves the property as it is.
            if isNull || expression != nil {
                converted.append((name, value, expression))
            }
        }
        var changes = currentChanges(ofLayer: layerId)
        defer { layerChanges[layerId] = changes }
        for property in converted {
            let exception = MapLibreGLCatchException {
                LayerPropertyConverter.setProperty(
                    property.name,
                    value: property.value,
                    expression: property.expression,
                    on: layer
                )
            }
            if let exception = exception {
                return rejectedProperty(
                    layerId: layerId,
                    property.name,
                    property.value,
                    exception.reason ?? exception.name.rawValue
                )
            }
            if property.expression == nil {
                changes.propertyNames.remove(property.name)
            } else {
                changes.propertyNames.insert(property.name)
            }
        }
        return nil
    }

    /// What this plugin changed on the layer `layerId`, starting from the
    /// style as loaded for a layer of the style it has not changed yet.
    private func currentChanges(ofLayer layerId: String) -> LayerChanges {
        return layerChanges[layerId]
            ?? LayerChanges(propertyNames: Self.propertyNames(in: loadedStyleLayer(layerId)))
    }

    /// The names of the paint and layout properties a style entry sets.
    private static func propertyNames(in entry: [String: Any]?) -> Set<String> {
        let paint = entry?["paint"] as? [String: Any] ?? [:]
        let layout = entry?["layout"] as? [String: Any] ?? [:]
        return Set(paint.keys).union(layout.keys)
    }

    /// The entry of the layer `layerId` in the style as it was loaded, or nil.
    private func loadedStyleLayer(_ layerId: String) -> [String: Any]? {
        let layers = currentStyleObject()?["layers"] as? [[String: Any]]
        return layers?.first { ($0["id"] as? String) == layerId }
    }

    /// The error of a property value MapLibre rejects, also logged.
    private func rejectedProperty(
        layerId: String,
        _ name: String,
        _ value: Any,
        _ reason: String
    ) -> MethodCallError {
        let error = MethodCallError.invalidLayerProperty(
            layerId: layerId,
            property: name,
            isExpression: Self.isExpression(value),
            reason: reason
        )
        NSLog("%@", "maplibre_gl: \(error.message)")
        return error
    }

    /// The style-spec type of `layer`, such as `circle`, or nil.
    private static func layerType(of layer: MLNStyleLayer) -> String? {
        switch layer {
        case is MLNLineStyleLayer: return "line"
        case is MLNFillStyleLayer: return "fill"
        case is MLNCircleStyleLayer: return "circle"
        case is MLNSymbolStyleLayer: return "symbol"
        case is MLNRasterStyleLayer: return "raster"
        case is MLNFillExtrusionStyleLayer: return "fill-extrusion"
        case is MLNHeatmapStyleLayer: return "heatmap"
        case is MLNHillshadeStyleLayer: return "hillshade"
        case is MLNColorReliefStyleLayer: return "color-relief"
        case is MLNBackgroundStyleLayer: return "background"
        default: return nil
        }
    }

    /// Whether `property` is a property of a layer of `layerType`: style-spec
    /// properties are named after their layer type.
    private static func isProperty(_ property: String, of layerType: String) -> Bool {
        if property == "visibility" { return true }
        switch layerType {
        case "symbol":
            return property.hasPrefix("symbol-") || property.hasPrefix("icon-")
                || property.hasPrefix("text-")
        case "fill":
            return property.hasPrefix("fill-") && !property.hasPrefix("fill-extrusion-")
        default:
            return property.hasPrefix("\(layerType)-")
        }
    }

    /// Whether `value`, a layer property value, reads as an expression: an
    /// array that starts with a string.
    private static func isExpression(_ value: Any) -> Bool {
        guard let array = value as? [Any] else { return false }
        return array.first is String
    }

    private static let propertyCheckId = "maplibre-gl-property-check"

    private lazy var propertyCheckSource = MLNShapeSource(
        identifier: Self.propertyCheckId,
        shape: nil,
        options: nil
    )

    /// A layer of the type of `layer` that is never added to a style, made
    /// once per type.
    private func propertyCheckLayer(like layer: MLNStyleLayer) -> MLNStyleLayer? {
        guard let layerType = Self.layerType(of: layer) else { return nil }
        if let check = propertyCheckLayers[layerType] {
            return check
        }
        let check = Self.newPropertyCheckLayer(like: layer, source: propertyCheckSource)
        propertyCheckLayers[layerType] = check
        return check
    }

    private static func newPropertyCheckLayer(
        like layer: MLNStyleLayer,
        source: MLNSource
    ) -> MLNStyleLayer? {
        let id = propertyCheckId
        switch layer {
        case is MLNLineStyleLayer: return MLNLineStyleLayer(identifier: id, source: source)
        case is MLNFillStyleLayer: return MLNFillStyleLayer(identifier: id, source: source)
        case is MLNCircleStyleLayer: return MLNCircleStyleLayer(identifier: id, source: source)
        case is MLNSymbolStyleLayer: return MLNSymbolStyleLayer(identifier: id, source: source)
        case is MLNRasterStyleLayer: return MLNRasterStyleLayer(identifier: id, source: source)
        case is MLNFillExtrusionStyleLayer:
            return MLNFillExtrusionStyleLayer(identifier: id, source: source)
        case is MLNHeatmapStyleLayer: return MLNHeatmapStyleLayer(identifier: id, source: source)
        case is MLNHillshadeStyleLayer: return MLNHillshadeStyleLayer(identifier: id, source: source)
        case is MLNColorReliefStyleLayer:
            return MLNColorReliefStyleLayer(identifier: id, source: source)
        case is MLNBackgroundStyleLayer: return MLNBackgroundStyleLayer(identifier: id)
        default: return nil
        }
    }

    /// Sets the zoom range, the filter and then the properties of `layer`,
    /// and adds it. A failed step leaves the style as it was.
    private func finishLayerAdd(
        _ layer: MLNStyleLayer,
        style: MLNStyle,
        belowLayerId: String?,
        sourceLayerIdentifier: String? = nil,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        filter: String? = nil,
        properties: [String: Any],
        enableInteraction: Bool = false
    ) -> Result<Void, MethodCallError> {
        // A new layer starts with nothing set, whatever the style once had
        // under its id, and is forgotten if it is not added.
        layerChanges[layer.identifier] = LayerChanges(isAdded: true, filter: NSNull())
        var isAdded = false
        defer {
            if !isAdded { layerChanges.removeValue(forKey: layer.identifier) }
        }
        if let sourceLayerIdentifier = sourceLayerIdentifier,
           let vectorLayer = layer as? MLNVectorStyleLayer
        {
            vectorLayer.sourceLayerIdentifier = sourceLayerIdentifier
        }
        if let minimumZoomLevel = minimumZoomLevel {
            layer.minimumZoomLevel = Float(minimumZoomLevel)
        }
        if let maximumZoomLevel = maximumZoomLevel {
            layer.maximumZoomLevel = Float(maximumZoomLevel)
        }
        if let filter = filter {
            if case let .failure(error) = setFilter(layer, filter) {
                return .failure(error)
            }
        }
        if let error = applyLayerProperties(properties, to: layer, layerId: layer.identifier) {
            return .failure(error)
        }
        if case let .failure(error) = insert(layer, into: style, below: belowLayerId) {
            return .failure(error)
        }
        isAdded = true
        if enableInteraction {
            interactiveFeatureLayerIds.insert(layer.identifier)
        }
        return .success(())
    }

    func addSymbolLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayerIdentifier: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "symbol",
            sourceLayer: sourceLayerIdentifier
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNSymbolStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    sourceLayerIdentifier: sourceLayerIdentifier,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    filter: filter,
                    properties: properties,
                    enableInteraction: enableInteraction
                )
            }
    }

    func addLineLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayerIdentifier: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "line",
            sourceLayer: sourceLayerIdentifier
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNLineStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    sourceLayerIdentifier: sourceLayerIdentifier,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    filter: filter,
                    properties: properties,
                    enableInteraction: enableInteraction
                )
            }
    }

    func addFillLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayerIdentifier: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "fill",
            sourceLayer: sourceLayerIdentifier
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNFillStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    sourceLayerIdentifier: sourceLayerIdentifier,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    filter: filter,
                    properties: properties,
                    enableInteraction: enableInteraction
                )
            }
    }

    func addFillExtrusionLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayerIdentifier: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "fill-extrusion",
            sourceLayer: sourceLayerIdentifier
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNFillExtrusionStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    sourceLayerIdentifier: sourceLayerIdentifier,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    filter: filter,
                    properties: properties,
                    enableInteraction: enableInteraction
                )
            }
    }

    func addCircleLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayerIdentifier: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "circle",
            sourceLayer: sourceLayerIdentifier
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNCircleStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    sourceLayerIdentifier: sourceLayerIdentifier,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    filter: filter,
                    properties: properties,
                    enableInteraction: enableInteraction
                )
            }
    }

    /// Sets `filter`, the JSON text of an expression, on `layer`. Nil, like
    /// the text `null`, removes its filter.
    func setFilter(_ layer: MLNStyleLayer, _ filter: String?) -> Result<Void, MethodCallError> {
        do {
            let filter = try filter.map {
                try JSONSerialization.jsonObject(
                    with: $0.data(using: .utf8)!,
                    options: .fragmentsAllowed
                )
            } ?? NSNull()
            guard let layer = layer as? MLNVectorStyleLayer else {
                return .failure(MethodCallError.invalidLayerType(
                    details: "Layer '\(layer.identifier)' does not support filtering."
                ))
            }
            // MapLibre raises an Objective-C exception for an invalid filter,
            // which would crash the app if it reached Swift.
            let exception = MapLibreGLCatchException {
                // A null filter removes the current one.
                layer.predicate = filter is NSNull ? nil : NSPredicate(mglJSONObject: filter)
            }
            if let exception = exception {
                return .failure(MethodCallError.invalidFilter(
                    reason: Self.filterRejection(exception)
                ))
            }
            var changes = currentChanges(ofLayer: layer.identifier)
            changes.filter = filter
            layerChanges[layer.identifier] = changes
            return .success(())
        } catch {
            return .failure(MethodCallError.invalidFilter(reason: Self.filterNotJSON))
        }
    }

    func addHillshadeLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "hillshade"
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNHillshadeStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    properties: properties
                )
            }
    }

    func addColorReliefLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "color-relief"
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNColorReliefStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    properties: properties
                )
            }
    }

    func addBackgroundLayer(
        layerId: String,
        belowLayerId: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        guard style.layer(withIdentifier: layerId) == nil else {
            return .failure(.layerAlreadyExists(layerId: layerId))
        }
        return finishLayerAdd(
            MLNBackgroundStyleLayer(identifier: layerId),
            style: style,
            belowLayerId: belowLayerId,
            minimumZoomLevel: minimumZoomLevel,
            maximumZoomLevel: maximumZoomLevel,
            properties: properties
        )
    }

    func addHeatmapLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayerIdentifier: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        filter: String?,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "heatmap",
            sourceLayer: sourceLayerIdentifier
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNHeatmapStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    sourceLayerIdentifier: sourceLayerIdentifier,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    filter: filter,
                    properties: properties
                )
            }
    }

    func addRasterLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        properties: [String: Any]
    ) -> Result<Void, MethodCallError> {
        validateBeforeLayerAdd(
            sourceId: sourceId,
            layerId: layerId,
            layerType: "raster"
        )
            .flatMap { style, source in
                finishLayerAdd(
                    MLNRasterStyleLayer(identifier: layerId, source: source),
                    style: style,
                    belowLayerId: belowLayerId,
                    minimumZoomLevel: minimumZoomLevel,
                    maximumZoomLevel: maximumZoomLevel,
                    properties: properties
                )
            }
    }

    func addSource(sourceId: String, properties: [String: Any]) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        guard style.source(withIdentifier: sourceId) == nil else {
            return .failure(.sourceAlreadyExists(sourceId: sourceId))
        }
        guard let type = properties["type"] as? String else {
            return .failure(.unsupportedSourceType(
                message: "Source '\(sourceId)' has no type."
            ))
        }
        if type == "video" {
            // MapLibre Native has no video source.
            return .failure(.unsupportedSourceType(
                message: "Source '\(sourceId)' is a video source. Video sources are only "
                    + "supported on web."
            ))
        }
        guard let build = Self.sourceBuilders[type] else {
            return .failure(.unsupportedSourceType(
                message: "Source '\(sourceId)' has the type '\(type)', which this platform "
                    + "does not support."
            ))
        }
        var built: MLNSource?
        // MapLibre raises an Objective-C exception for some properties, such as
        // a cluster property that is not an expression.
        let exception = MapLibreGLCatchException {
            built = build(sourceId, properties)
        }
        guard exception == nil, let source = built else {
            return .failure(.unbuildableSource(sourceId: sourceId, type: type))
        }
        style.addSource(source)
        // setGeoJsonFeature edits only data this API was given as GeoJSON.
        addedShapesByLayer.removeValue(forKey: sourceId)
        sourceAttributions[sourceId] = properties["attribution"] as? String
        return .success(())
    }

    /// The builder of each source type MapLibre Native has, which answers nil
    /// for properties that describe no source of that type.
    private static let sourceBuilders: [String: (String, [String: Any]) -> MLNSource?] = [
        "vector": { SourcePropertyConverter.buildVectorTileSource(identifier: $0, properties: $1) },
        "raster": { SourcePropertyConverter.buildRasterTileSource(identifier: $0, properties: $1) },
        "raster-dem": { SourcePropertyConverter.buildRasterDemSource(identifier: $0, properties: $1) },
        "image": { id, properties in
            SourcePropertyConverter.isImageSource(properties)
                ? SourcePropertyConverter.buildImageSource(identifier: id, properties: properties)
                : nil
        },
        "geojson": { SourcePropertyConverter.buildShapeSource(identifier: $0, properties: $1) },
    ]

    func mapViewWillStartRenderingFrame(_: MLNMapView) {
        guard pendingInitialCamera != nil || !callsWaitingForSize.isEmpty else { return }
        // A frame is drawn once the view has a size. Apply outside the render
        // callback; a Dart call that gets there first applies it and this is a no-op.
        DispatchQueue.main.async { [weak self] in
            self?.applyInitialCameraIfNeeded()
            self?.runCallsWaitingForSize()
        }
    }

    func mapViewDidBecomeIdle(_: MLNMapView) {
        flutterApi?.mapOnIdle { _ in }
    }

    // MLNMapView calls this instead of regionWillChangeAnimated, which takes no reason.
    func mapView(
        _ mapView: MLNMapView,
        regionWillChangeWith reason: MLNCameraChangeReason,
        animated _: Bool
    ) {
        // Whether a gesture of the user moves the camera, which Android tells
        // with REASON_API_GESTURE.
        let isGesture = !reason.isDisjoint(with: .gestures)
        flutterApi?.cameraOnMoveStarted(isGesture: isGesture) { _ in }
        // Where the change starts, so regionDidChange can tell whether the camera moved.
        lastMovePosition = getCamera()?.toPigeon(mapView: mapView)
    }

    func mapViewRegionIsChanging(_ mapView: MLNMapView) {
        // Never nil when the position is tracked: getCamera() answers whenever it is.
        guard let camera = getCamera() else { return }
        sendCameraMove(camera.toPigeon(mapView: mapView))
    }

    private func sendCameraMove(_ position: PgCameraPosition) {
        lastMovePosition = position
        flutterApi?.cameraOnMove(position: position) { _ in }
    }

    func mapView(_: MLNMapView, shouldChangeFrom _: MLNMapCamera, to _: MLNMapCamera) -> Bool {
        // Only gestures ask this, each right after cancelling the running animation.
        cameraAnimations.interruptRunning()
        return true
    }

    // MLNMapView calls this instead of regionDidChangeAnimated, which takes no reason.
    func mapView(
        _ mapView: MLNMapView,
        regionDidChangeWith reason: MLNCameraChangeReason,
        animated: Bool
    ) {
        cameraAnimations.regionDidChange(reason: reason, animated: animated)
        // Null when the map does not track the camera position: getCamera()
        // answers only when it does.
        let position = getCamera()?.toPigeon(mapView: mapView)
        // MLNMapView reports no change in progress for a move without animation, such as
        // moveCamera, nor for the last frame of an animation. Android sends every position the
        // camera reaches to onCameraMove before onCameraIdle, so the final one goes out here
        // when Dart does not have it yet (#1122).
        if let position = position, position != lastMovePosition {
            sendCameraMove(position)
        }
        flutterApi?.cameraOnIdle(position: position) { _ in }
    }

    func addSourceGeojson(sourceId: String, geojson: String) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        guard style.source(withIdentifier: sourceId) == nil else {
            return .failure(.sourceAlreadyExists(sourceId: sourceId))
        }
        let read = readShape(fromGeoJson: geojson)
        guard let parsed = read.shape else {
            return .failure(unreadableGeoJson(sourceId: sourceId, read.reason))
        }
        let source = MLNShapeSource(identifier: sourceId, shape: parsed, options: [:])
        style.addSource(source)
        // Replaces the data of any earlier source with this id.
        addedShapesByLayer[sourceId] = parsed
        return .success(())
    }

    func setSource(sourceId: String, geojson: String) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        // The source is looked up first, so a bad id wins over bad data, as on
        // Android.
        let source: MLNShapeSource
        switch shapeSource(style, sourceId, methodName: "setGeoJsonSource") {
        case let .success(found): source = found
        case let .failure(error): return .failure(error)
        }
        let read = readShape(fromGeoJson: geojson)
        guard let parsed = read.shape else {
            return .failure(unreadableGeoJson(sourceId: sourceId, read.reason))
        }
        addedShapesByLayer[sourceId] = parsed
        source.shape = parsed
        return .success(())
    }

    /// The GeoJSON source `sourceId` that `methodName` works on, or
    /// SOURCE_NOT_FOUND without it and UNSUPPORTED_SOURCE_TYPE for a source of
    /// another type.
    private func shapeSource(
        _ style: MLNStyle,
        _ sourceId: String,
        methodName: String
    ) -> Result<MLNShapeSource, MethodCallError> {
        guard let source = style.source(withIdentifier: sourceId) else {
            return .failure(.sourceNotFound(sourceId: sourceId))
        }
        guard let shapeSource = source as? MLNShapeSource else {
            return .failure(.notGeoJsonSource(sourceId: sourceId, methodName: methodName))
        }
        return .success(shapeSource)
    }

    /// `geojson` as a shape, or nil when MapLibre cannot read it.
    private func shape(fromGeoJson geojson: String) -> MLNShape? {
        return readShape(fromGeoJson: geojson).shape
    }

    /// `geojson` as a shape, or why MapLibre cannot read it.
    private func readShape(fromGeoJson geojson: String) -> (shape: MLNShape?, reason: String) {
        guard let data = geojson.data(using: .utf8) else { return (nil, "Not UTF-8.") }
        do {
            return (try MLNShape(data: data, encoding: String.Encoding.utf8.rawValue), "")
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    /// GeoJSON data MapLibre cannot read. The Dart side checks the data first,
    /// with a message of the same shape.
    private func unreadableGeoJson(sourceId: String, _ reason: String) -> MethodCallError {
        return .invalidGeoJson(
            message: "The data for source '\(sourceId)' is not GeoJSON: \(reason)"
        )
    }

    /// The source a feature state call addresses, with the source layer a
    /// vector source needs.
    private enum FeatureStateTarget {
        case shape(MLNShapeSource)
        case vector(MLNVectorTileSource, sourceLayer: String)
    }

    /// Resolves the source a feature state call addresses.
    ///
    /// Only GeoJSON and vector sources carry the API. On a vector source every
    /// call is scoped to a source layer, so a missing `sourceLayer` would leave
    /// the call with nothing to address; that is rejected here once instead of
    /// in each feature state call.
    private func featureStateTarget(
        sourceId: String,
        sourceLayer: String?
    ) -> Result<FeatureStateTarget, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        guard let source = style.source(withIdentifier: sourceId) else {
            return .failure(.sourceNotFound(sourceId: sourceId))
        }
        if let vectorSource = source as? MLNVectorTileSource {
            guard let sourceLayer = sourceLayer else {
                return .failure(.featureStateSourceLayerRequired(sourceId: sourceId))
            }
            return .success(.vector(vectorSource, sourceLayer: sourceLayer))
        }
        if let shapeSource = source as? MLNShapeSource {
            return .success(.shape(shapeSource))
        }
        let typeName = String(describing: type(of: source)).replacingOccurrences(of: "MLN", with: "")
        return .failure(.unsupportedSourceType(
            message: "Source '\(sourceId)' is a \(typeName). Feature state only applies to "
                + "GeoJSON and vector sources."
        ))
    }

    /// Resolves the shape source a cluster-inspection call addresses.
    ///
    /// Clustering is a shape (GeoJSON) source feature, and the iOS SDK exposes
    /// the inspection methods on `MLNShapeSource` only.
    func clusterSource(
        sourceId: String,
        methodName: String
    ) -> Result<MLNShapeSource, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        guard let source = style.source(withIdentifier: sourceId) else {
            return .failure(.sourceNotFound(sourceId: sourceId))
        }
        guard let shapeSource = source as? MLNShapeSource else {
            return .failure(.notGeoJsonSource(
                sourceId: sourceId,
                methodName: methodName,
                clustered: true
            ))
        }
        return .success(shapeSource)
    }

    /// Whether the source currently holds a cluster with this id.
    ///
    /// For an id it does not hold, MapLibre Native throws a C++ exception from
    /// the cluster calls. Swift cannot catch it, so the app aborts. Ids go stale
    /// as the data or the viewport changes, so an app can pass one without doing
    /// anything wrong. Looking the id up first lets the cluster calls reply
    /// CLUSTER_NOT_FOUND instead. Only loaded tiles are searched, which holds
    /// for any id the app just read off a feature on screen.
    private func hasCluster(_ source: MLNShapeSource, clusterId: Int) -> Bool {
        let predicate = NSPredicate(format: "cluster_id == %@", NSNumber(value: clusterId))
        return !source.features(matching: predicate).isEmpty
    }

    private func clusterNotFoundError(sourceId: String, clusterId: Int) -> FlutterError {
        return FlutterError(
            code: "CLUSTER_NOT_FOUND",
            message: "Cluster '\(clusterId)' is not one of the current clusters of source "
                + "'\(sourceId)'. Cluster ids are reassigned as the data or the viewport "
                + "changes, so read the id from a freshly queried feature.",
            details: nil
        )
    }

    /// Builds the argument the SDK's cluster methods take.
    ///
    /// They are declared as taking an `MLNPointFeatureCluster`, but everything
    /// below them reads a single attribute off it: the source converts the
    /// feature to GeoJSON and the renderer looks up `cluster_id` in the source's
    /// supercluster index, ignoring the coordinate and every other attribute. A
    /// minimal point feature carrying the id is therefore the whole input, which
    /// is what lets the Dart API be an Int.
    ///
    /// The id has to stay an integer `NSNumber`: the renderer only accepts an
    /// unsigned integer there, and a floating-point one would be ignored,
    /// leaving every call to report an empty result.
    private func clusterFeature(_ clusterId: Int) -> MLNPointFeatureCluster {
        let feature = MLNPointFeatureCluster()
        feature.attributes = ["cluster_id": NSNumber(value: clusterId)]
        return feature
    }

    private func invalidArgumentError(_ message: String) -> FlutterError {
        return FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil)
    }

    /// Image bytes that do not decode.
    private func invalidImageError() -> FlutterError {
        return FlutterError(code: "INVALID_IMAGE", message: "Failed to decode image bytes.", details: nil)
    }

    /// A call that needs a style while none is loaded.
    private func styleNotReadyError() -> FlutterError {
        return MethodCallError.styleNotReady.flutterError
    }

    /// Answers a call with nothing, or with the error it failed with.
    private func answer(_ outcome: Result<Void, MethodCallError>, _ result: FlutterResult) {
        switch outcome {
        case .success: result(nil)
        case let .failure(error): result(error.flutterError)
        }
    }

    /// The camera `cameraUpdate` moves to. For an update with a NaN or
    /// infinite value, or of a kind this side does not know, answers the call
    /// with INVALID_ARGUMENT and returns nil.
    private func targetCamera(of cameraUpdate: PgCameraUpdate, _ result: FlutterResult) -> MLNMapCamera? {
        if let reason = Convert.nonFiniteReason(cameraUpdate) {
            result(invalidArgumentError(reason))
            return nil
        }
        guard let camera = Convert.camera(for: cameraUpdate, mapView: mapView) else {
            result(invalidArgumentError("Cannot interpret \(cameraUpdate) as CameraUpdate."))
            return nil
        }
        return camera
    }

    /// Serializes features as JSON strings, so nested properties survive
    /// intact, and answers the list of them.
    ///
    /// Returns a `FlutterError` if any feature fails to serialize, rather than
    /// skipping it. A short list is worse than an error: the caller has no way
    /// to tell that something is missing, a cluster caller paging through
    /// leaves by `point_count` would silently step over the gap, and Android
    /// cannot lose a feature this way, so dropping one would also make the two
    /// platforms disagree on the same call.
    private func featuresReply(
        _ features: [MLNFeature],
        methodName: String
    ) -> Any {
        var featuresJson = [String]()
        for (index, feature) in features.enumerated() {
            let dictionary = feature.geoJSONDictionary()
            // JSONSerialization raises an Objective-C exception, which Swift
            // cannot catch, for an object it considers invalid: a non-finite
            // coordinate, or an attribute of a type it does not write. Asking
            // first is what turns that trap into the error below.
            guard JSONSerialization.isValidJSONObject(dictionary),
                  let json = jsonString(from: dictionary)
            else {
                let identifier = feature.identifier ?? "none"
                let details: String = "Feature at index \(index) of "
                    + "\(features.count), id \(identifier), is not valid JSON: "
                    + "it holds a non-finite number, or a value of a type JSON "
                    + "cannot carry. The \(featuresJson.count) features before "
                    + "it encoded fine."
                return FlutterError(
                    code: "FEATURE_ENCODING_FAILED",
                    message: "\(methodName) could not encode one of the features "
                        + "it found as GeoJSON, so the result would have been "
                        + "incomplete without saying so.",
                    details: details
                )
            }
            featuresJson.append(json)
        }
        return featuresJson
    }

    /// Replaces the feature with the id of `geojsonFeature` in the data
    /// addSourceGeojson or setSource gave the source.
    ///
    /// A source without such data and an id the data does not hold change
    /// nothing, as on Android and web. Data that is a lone Feature counts as a
    /// collection of one.
    func setFeature(sourceId: String, geojsonFeature: String) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotReady)
        }
        let source: MLNShapeSource
        switch shapeSource(style, sourceId, methodName: "setGeoJsonFeature") {
        case let .success(found): source = found
        case let .failure(error): return .failure(error)
        }
        // Only a Feature replaces a feature. Its type is read from the JSON:
        // MapLibre reads a FeatureCollection as a feature too.
        guard let data = geojsonFeature.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["type"] as? String == "Feature",
              let feature = shape(fromGeoJson: geojsonFeature) as? MLNShape & MLNFeature
        else {
            return .failure(.invalidGeoJson(
                message: "The feature for source '\(sourceId)' is not a GeoJSON Feature."
            ))
        }
        let shapes: [MLNShape & MLNFeature]
        let stored = addedShapesByLayer[sourceId]
        if let collection = stored as? MLNShapeCollectionFeature {
            shapes = collection.shapes
        } else if let lone = stored as? MLNShape & MLNFeature {
            shapes = [lone]
        } else {
            return .success(())
        }
        let featureId = Self.featureIdKey(feature.identifier)
        guard featureId != nil,
              let index = shapes.firstIndex(where: { Self.featureIdKey($0.identifier) == featureId })
        else {
            return .success(())
        }
        var updated = shapes
        updated[index] = feature
        let collection = MLNShapeCollectionFeature(shapes: updated)
        source.shape = collection
        addedShapesByLayer[sourceId] = collection
        return .success(())
    }

    /// A feature id as text, so 2 and "2" match.
    private static func featureIdKey(_ identifier: Any?) -> String? {
        if let id = identifier as? String { return id }
        if let id = identifier as? NSNumber { return id.stringValue }
        return nil
    }

    /*
     *  MapLibreMapOptionsSink
     */
    func setCameraTargetBounds(bounds: MLNCoordinateBounds?) {
        let bounds = bounds ?? MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: -90, longitude: -180),
            ne: CLLocationCoordinate2D(latitude: 90, longitude: 180)
        )
        mapView.maximumScreenBounds = bounds;
    }

    func setCompassEnabled(compassEnabled: Bool) {
        mapView.compassView.isHidden = compassEnabled
        mapView.compassView.isHidden = !compassEnabled
    }

    func setMinMaxZoomPreference(min: Double?, max: Double?) {
        // Use MapLibre defaults (0 for min, 22 for max) when unbounded (nil)
        let minZoom = min ?? 0.0
        let maxZoom = max ?? 22.0

        mapView.minimumZoomLevel = minZoom
        mapView.maximumZoomLevel = maxZoom
    }

    /// The style URL a snapshotter can load for the current style.
    ///
    /// The snapshotter only takes a URL. A style set as JSON has no real one,
    /// and the snapshotter rejects what the map reports as unsupported. Such a
    /// style is written to a temporary file and snapshotted from there. The
    /// file name is unique so maps snapshotting at once do not overwrite each
    /// other's style.
    private func snapshotStyleURL() -> URL? {
        if !styleIsJSON {
            return mapView.styleURL
        }
        guard mapView.style != nil, let data = mapView.styleJSON.data(using: .utf8) else {
            return nil
        }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("maplibre_gl_snapshot_style_\(UUID().uuidString).json")
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            return nil
        }
        return file
    }

    private static func styleStringIsJSON(_ styleString: String) -> Bool {
        return styleString.hasPrefix("{") || styleString.hasPrefix("[")
    }

    private static func styleStringAsURL(
        _ styleString: String,
        registrar: FlutterPluginRegistrar
    ) -> URL? {
        if styleString.isEmpty {
            NSLog("styleStringAsURL - style string is empty, ignoring")
            return nil
        } else if styleStringIsJSON(styleString) {
            return nil
        } else if styleString.hasPrefix("/") {
            // Absolute path
            return URL(fileURLWithPath: styleString, isDirectory: false)
        } else if !styleString.hasPrefix("http://"),
            !styleString.hasPrefix("https://"),
            !styleString.hasPrefix("mapbox://")
        {
            // We are assuming that the style will be loaded from an asset here.
            let assetPath = registrar.lookupKey(forAsset: styleString)
            return URL(string: assetPath, relativeTo: Bundle.main.resourceURL)
        } else if (styleString.hasPrefix("file://")) {
            if let path = Bundle.main.path(
                forResource: styleString.deletingPrefix("file://"),
                ofType: "json"
            ) {
                return URL(fileURLWithPath: path)
            } else {
                NSLog(
                    "styleStringAsURL - path not found: \(styleString), ignoring"
                )
                return nil
            }
        } else {
            return URL(string: styleString)
        }
    }

    func setStyleString(styleString: String) {
        interactiveFeatureLayerIds.removeAll()
        addedShapesByLayer.removeAll()
        layerChanges.removeAll()
        sourceAttributions.removeAll()

        styleIsJSON = Self.styleStringIsJSON(styleString)
        if styleIsJSON {
            mapView.styleJSON = styleString
        } else if let url = Self.styleStringAsURL(
            styleString,
            registrar: registrar
        ) {
            mapView.styleURL = url;
        }
    }

    func setRotateGesturesEnabled(rotateGesturesEnabled: Bool) {
        mapView.allowsRotating = rotateGesturesEnabled
    }

    func setScrollGesturesEnabled(scrollGesturesEnabled: Bool) {
        mapView.allowsScrolling = scrollGesturesEnabled
        scrollingEnabled = scrollGesturesEnabled
    }

    /// Maps the Dart `PanInertia` onto `decelerationRate`. The SDK glides
    /// for `rate` seconds over `velocity * rate / 4` points, and skips gestures
    /// slower than 100 pt/s:
    /// - none: `.immediate` (0), no glide.
    /// - short: half of `.normal`, so about half the time and distance.
    ///   `.fast` (0.99) is not used: it glides almost exactly like `.normal`.
    /// - normal: `.normal` (0.998), the SDK default.
    /// The same rate also drives the glide after a pinch or a rotation.
    func setPanInertia(panInertia: PgPanInertia) {
        switch panInertia {
        case PgPanInertia.none:
            mapView.decelerationRate = MLNMapViewDecelerationRate.immediate.rawValue
        case .short:
            mapView.decelerationRate = MLNMapViewDecelerationRate.normal.rawValue / 2
        case .normal:
            mapView.decelerationRate = MLNMapViewDecelerationRate.normal.rawValue
        }
    }

    func setTiltGesturesEnabled(tiltGesturesEnabled: Bool) {
        mapView.allowsTilting = tiltGesturesEnabled
    }

    func setHapticFeedbackEnabled(hapticFeedbackEnabled: Bool) {
        // The SDK plays a light impact when a rotate gesture crosses due north.
        mapView.isHapticFeedbackEnabled = hapticFeedbackEnabled
    }

    func setTrackCameraPosition(trackCameraPosition: Bool) {
        self.trackCameraPosition = trackCameraPosition
    }

    func setZoomGesturesEnabled(zoomGesturesEnabled: Bool) {
        mapView.allowsZooming = zoomGesturesEnabled
    }

    func setDoubleClickZoomEnabled(doubleClickZoomEnabled: Bool) {
        for recognizer in doubleTapRecognizers {
            recognizer.isEnabled = doubleClickZoomEnabled
        }
    }

    func setMyLocationEnabled(myLocationEnabled: Bool) {
        if self.myLocationEnabled == myLocationEnabled {
            return
        }
        self.myLocationEnabled = myLocationEnabled
        updateMyLocationEnabled()
        // The puck comes back where the app last put it, even if that was
        // while it was hidden.
        if myLocationEnabled, manualLocationSource, mapView.showsUserLocation,
           let location = lastManualLocation
        {
            manualLocationManager.push(location)
        }
    }

    func setMyLocationTrackingMode(myLocationTrackingMode: MLNUserTrackingMode) {
        mapView.userTrackingMode = myLocationTrackingMode
    }

    func setLocationEngineProperties(
        enableHighAccuracy: Bool,
        distanceFilter: Double,
        intervalMs: Int,
        pulseWindowMs: Int
    ) {
        guard let locationManager = mapView.locationManager else { return }
        let accuracy = enableHighAccuracy
            ? kCLLocationAccuracyBest
            : kCLLocationAccuracyHundredMeters
        let filter = distanceFilter > 0
            ? distanceFilter
            : kCLDistanceFilterNone
        locationManager.setDesiredAccuracy?(accuracy)
        locationManager.setDistanceFilter?(filter)

        let resolvedPulseWindowMs = pulseWindowMs > 0
            ? pulseWindowMs
            : Self.defaultPulseWindowMs
        if locationUpdateIntervalMs != intervalMs
            || locationPulseWindowMs != resolvedPulseWindowMs
        {
            locationUpdateIntervalMs = intervalMs
            locationPulseWindowMs = resolvedPulseWindowMs
            restartLocationPulseIfNeeded()
        }
    }

    private func restartLocationPulseIfNeeded() {
        locationPulseTimer?.invalidate()
        locationPulseTimer = nil
        locationPulseWindowTimer?.invalidate()
        locationPulseWindowTimer = nil

        guard myLocationEnabled else {
            setLocationUpdatesActive(false)
            mapView.showsUserLocation = false
            return
        }

        // A manual source has to own `mapView.locationManager` before
        // `showsUserLocation` is first enabled: turning it on while the default
        // manager is still in place asks for location permission, which is what
        // manual mode exists to avoid. Updates then arrive via
        // locationComponentSetManualLocation -> manualLocationManager.push.
        if manualLocationSource, !(mapView.locationManager is ManualLocationManager) {
            mapView.locationManager = manualLocationManager
        }

        // Keep the blue dot at the last known position between GPS pulses.
        mapView.showsUserLocation = true

        // App-provided locations have no Core Location duty cycle to pulse, and
        // ManualLocationManager implements start/stopUpdatingLocation as no-ops,
        // so the pulse timers would only burn cycles.
        guard !manualLocationSource else { return }

        // Paused from Dart or in the background: the puck stays at its last
        // position and Core Location stays off until mapResume or the
        // foreground handler calls this again (#1094).
        guard !pausedByDart && !isBackgroundPaused else {
            setLocationUpdatesActive(false)
            return
        }

        guard locationUpdateIntervalMs > 0 else {
            setLocationUpdatesActive(true)
            return
        }

        fireLocationPulse()

        let interval = TimeInterval(locationUpdateIntervalMs) / 1000.0
        locationPulseTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.fireLocationPulse()
        }
    }

    private func fireLocationPulse() {
        setLocationUpdatesActive(true)

        let windowSec = TimeInterval(locationPulseWindowMs) / 1000.0
        locationPulseWindowTimer?.invalidate()
        locationPulseWindowTimer = Timer.scheduledTimer(
            withTimeInterval: windowSec,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.locationUpdateIntervalMs > 0 {
                self.setLocationUpdatesActive(false)
            }
        }
    }

    func setLocationSource(source: PgLocationSource) {
        // Applied before `showsUserLocation` is first enabled; runtime changes
        // do not re-activate the component.
        manualLocationSource = (source == .manual)
    }

    func setMyLocationStyle(style: LocationPuckStyle) {
        guard style != locationPuckStyle else { return }
        locationPuckStyle = style
        applyLocationPuckTint()
    }

    func setMyLocationRenderMode(myLocationRenderMode: PgMyLocationRenderMode) {
        switch myLocationRenderMode {
        case .normal:
            mapView.showsUserHeadingIndicator = false
        case .compass:
            mapView.showsUserHeadingIndicator = true
        case .gps:
            NSLog("RenderMode.GPS currently not supported")
        }
    }

    func setLogoEnabled(logoEnabled: Bool) {
        mapView.logoView.isHidden = !logoEnabled
    }

    func setLogoViewPosition(position: MLNOrnamentPosition) {
        mapView.logoViewPosition = position
    }

    func setLogoViewMargins(x: Double, y: Double) {
        mapView.logoViewMargins = CGPoint(x: x, y: y)
    }

    func setCompassViewPosition(position: MLNOrnamentPosition) {
        mapView.compassViewPosition = position
    }

    func setCompassViewMargins(x: Double, y: Double) {
        mapView.compassViewMargins = CGPoint(x: x, y: y)
    }

    func setAttributionEnabled(attributionEnabled: Bool) {
        mapView.attributionButton.isHidden = !attributionEnabled
    }

    func setAttributionButtonMargins(x: Double, y: Double) {
        mapView.attributionButtonMargins = CGPoint(x: x, y: y)
    }

    func setAttributionButtonPosition(position: MLNOrnamentPosition) {
        mapView.attributionButtonPosition = position
    }

    func setAttributionButtonColor(color: Int) {
        mapView.attributionButton.tintColor = UIColor(
            red: CGFloat((color >> 16) & 0xFF) / 255.0,
            green: CGFloat((color >> 8) & 0xFF) / 255.0,
            blue: CGFloat(color & 0xFF) / 255.0,
            alpha: CGFloat((color >> 24) & 0xFF) / 255.0
        )
    }

    func setFeatureTapsTriggersMapClick(triggers: Bool) {
        featureTapsTriggersMapClick = triggers
    }

    func setSymbolPlacementTransitionsEnabled(enabled: Bool) {
        symbolPlacementTransitionsEnabled = enabled
        mapView.style?.performsPlacementTransitions = enabled
        // With transitions off nothing asks MapLibre for another frame once
        // placement is done, so data placed while they were off can stay
        // undrawn until the map next moves. One frame now draws it.
        mapView.triggerRepaint()
    }
}

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
