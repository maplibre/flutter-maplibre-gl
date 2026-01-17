import Flutter
import MapLibre

class MapLibreMapController: NSObject, FlutterPlatformView, MLNMapViewDelegate, MapLibreMapOptionsSink,
    UIGestureRecognizerDelegate
{
    private var registrar: FlutterPluginRegistrar
    private var channel: FlutterMethodChannel?

    private var mapView: MLNMapView
    private var isMapReady = false
    private var dragEnabled = true
    private var featureTapsTriggersMapClick = false
    private var isFirstStyleLoad = true
    private var onStyleLoadedCalled = false
    private var mapReadyResult: FlutterResult?
    private var previousDragCoordinate: CLLocationCoordinate2D?
    private var originDragCoordinate: CLLocationCoordinate2D?
    private var dragFeature: MLNFeature?

    private var initialTilt: CGFloat?
    private var trackCameraPosition = false
    private var myLocationEnabled = false
    private var scrollingEnabled = true
    private var isAdjustingCameraProgrammatically = false

    private var interactiveFeatureLayerIds = Set<String>()
    private var addedShapesByLayer = [String: MLNShape]()

    func view() -> UIView {
        return mapView
    }

    private var styleIsReady: Bool {
        return onStyleLoadedCalled && mapView.style != nil
    }

    private static func createMapView(
        args: Any?,
        frame: CGRect,
        registrar: FlutterPluginRegistrar
    ) -> MLNMapView {
        if let args = args as? [String: Any],
            let styleString = args["styleString"] as? String
        {
            if Self.styleStringIsJSON(styleString) {
                return MLNMapView(frame: frame, styleJSON: styleString)
            }

            if let url = Self.styleStringAsURL(
                styleString,
                registrar: registrar
            ) {
                return MLNMapView(frame: frame, styleURL: url)
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
        return MLNMapView(frame: frame)
    }

    init(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        registrar: FlutterPluginRegistrar
    ) {
        mapView = Self.createMapView(
            args: args,
            frame: frame,
            registrar: registrar
        )

        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.registrar = registrar

        super.init()

        channel = FlutterMethodChannel(
            name: "plugins.flutter.io/maplibre_gl_\(viewId)",
            binaryMessenger: registrar.messenger()
        )
        channel!
            .setMethodCallHandler { [weak self] in self?.onMethodCall(methodCall: $0, result: $1) }

        mapView.delegate = self

        let singleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleMapTap(sender:))
        )
        for recognizer in mapView.gestureRecognizers!
        where (recognizer as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 {
            singleTap.require(toFail: recognizer)
        }
        mapView.addGestureRecognizer(singleTap)

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleMapLongPress(sender:))
        )
        var longPressRecognizerAdded = false

        if let args = args as? [String: Any] {

            Convert.interpretMapLibreMapOptions(options: args["options"], delegate: self)
            if let initialCameraPosition = args["initialCameraPosition"] as? [String: Any],
               let camera = MLNMapCamera.fromDict(initialCameraPosition, mapView: mapView),
               let zoom = initialCameraPosition["zoom"] as? Double
            {
                mapView.setCenter(
                    camera.centerCoordinate,
                    zoomLevel: zoom,
                    direction: camera.heading,
                    animated: false
                )
                initialTilt = camera.pitch
            }
            // if let onAttributionClickOverride = args["onAttributionClickOverride"] as? Bool {
            //     if onAttributionClickOverride {
            //         setupAttribution(mapView)
            //     }
            // }

            if let enabled = args["dragEnabled"] as? Bool {
                dragEnabled = enabled
            }

            if let iosLongClickDurationMilliseconds = args["iosLongClickDurationMilliseconds"] as? Int {
                longPress.minimumPressDuration = TimeInterval(iosLongClickDurationMilliseconds) / 1000
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
        }

        if(!longPressRecognizerAdded) {
            mapView.addGestureRecognizer(longPress)
            longPressRecognizerAdded = true
        }
    }

    func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    func onMethodCall(methodCall: FlutterMethodCall, result: @escaping FlutterResult) {
        switch methodCall.method {
        case "map#waitForMap":
            if isMapReady {
                result(nil)
                // only call map#onStyleLoaded here if isMapReady has happend and isFirstStyleLoad is true
                if isFirstStyleLoad {
                    isFirstStyleLoad = false
                    if let channel = channel {
                        onStyleLoadedCalled = true
                        // Defer the callback to the next run loop iteration to avoid race conditions
                        DispatchQueue.main.async {
                            channel.invokeMethod("map#onStyleLoaded", arguments: nil)
                        }
                    }
                }
            } else {
                mapReadyResult = result
            }
        case "map#update":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            Convert.interpretMapLibreMapOptions(options: arguments["options"], delegate: self)
            if let camera = getCamera() {
                result(camera.toDict(mapView: mapView))
            } else {
                result(nil)
            }
        case "map#invalidateAmbientCache":
            MLNOfflineStorage.shared.invalidateAmbientCache {
                error in
                if let error = error {
                    result(error)
                } else {
                    result(nil)
                }
            }
        case "map#clearAmbientCache":
            MLNOfflineStorage.shared.clearAmbientCache {
                error in
                if let error = error {
                    result(error)
                } else {
                    result(nil)
                }
            }
        case "map#updateMyLocationTrackingMode":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let myLocationTrackingMode = arguments["mode"] as? UInt,
               let trackingMode = MLNUserTrackingMode(rawValue: myLocationTrackingMode)
            {
                setMyLocationTrackingMode(myLocationTrackingMode: trackingMode)
            }
            result(nil)
        case "map#matchMapLanguageWithDeviceDefault":
            if let langStr = Locale.current.languageCode {
                setMapLanguage(language: langStr)
            }

            result(nil)
        case "map#updateContentInsets":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }

            if let bounds = arguments["bounds"] as? [String: Any],
               let top = bounds["top"] as? CGFloat,
               let left = bounds["left"] as? CGFloat,
               let bottom = bounds["bottom"] as? CGFloat,
               let right = bounds["right"] as? CGFloat,
               let animated = arguments["animated"] as? Bool
            {
                mapView.setContentInset(
                    UIEdgeInsets(top: top, left: left, bottom: bottom, right: right),
                    animated: animated
                ) {
                    result(nil)
                }
            } else {
                result(nil)
            }
        case "locationComponent#getLastLocation":
            var reply = [String: NSObject]()
            if let loc = mapView.userLocation?.location?.coordinate {
                reply["latitude"] = loc.latitude as NSObject
                reply["longitude"] = loc.longitude as NSObject
                result(reply)
            } else {
                result(nil)
            }
        case "map#setMapLanguage":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let localIdentifier = arguments["language"] as? String {
                setMapLanguage(language: localIdentifier)
            }
            result(nil)
        case "map#queryRenderedFeatures":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            var styleLayerIdentifiers: Set<String>?
            if let layerIds = arguments["layerIds"] as? [String], !layerIds.isEmpty {
                styleLayerIdentifiers = Set<String>(layerIds)
            }
            var filterExpression: NSPredicate?
            if let filter = arguments["filter"] as? [Any] {
                filterExpression = NSPredicate(mglJSONObject: filter)
            }
            var reply = [String: NSObject]()
            var features: [MLNFeature] = []
            if let x = arguments["x"] as? Double, let y = arguments["y"] as? Double {
                features = mapView.visibleFeatures(
                    at: CGPoint(x: x, y: y),
                    styleLayerIdentifiers: styleLayerIdentifiers,
                    predicate: filterExpression
                )
            }
            if let top = arguments["top"] as? Double,
               let bottom = arguments["bottom"] as? Double,
               let left = arguments["left"] as? Double,
               let right = arguments["right"] as? Double
            {
                var width = right - left
                var height = bottom - top
                features = mapView.visibleFeatures(in: CGRect(x: left, y: top, width: width, height: height), styleLayerIdentifiers: styleLayerIdentifiers, predicate: filterExpression)
            }
            var featuresJson = [String]()
            for feature in features {
                let dictionary = feature.geoJSONDictionary()
                if let theJSONData = try? JSONSerialization.data(
                    withJSONObject: dictionary,
                    options: []
                ),
                    let theJSONText = String(data: theJSONData, encoding: .utf8)
                {
                    featuresJson.append(theJSONText)
                }
            }
            reply["features"] = featuresJson as NSObject
            result(reply)
        case "map#setTelemetryEnabled":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            let telemetryEnabled = arguments["enabled"] as? Bool
            UserDefaults.standard.set(telemetryEnabled, forKey: "MLNMapboxMetricsEnabled")
            result(nil)
        case "map#getTelemetryEnabled":
            let telemetryEnabled = UserDefaults.standard.bool(forKey: "MLNMapboxMetricsEnabled")
            result(telemetryEnabled)
        case "map#setMaximumFps":
            result(nil)
        case "map#forceOnlineMode":
            // Force online mode by ensuring network requests are enabled
            // In MapLibre GL iOS, this is typically handled by the style and data sources
            result(nil)
        case "camera#ease":
            guard let arguments = methodCall.arguments as? [String: Any] else { 
                result(false)
                return 
            }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { 
                result(false)
                return 
            }
            guard let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) else { 
                result(false)
                return 
            }

            let completion = {
                result(true)
            }

            if let duration = arguments["duration"] as? Double, duration > 0 {
                let interval: TimeInterval = duration / 1000.0
                mapView.setCamera(camera, withDuration: interval, animationTimingFunction: CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut), completionHandler: completion)
            } else {
                mapView.setCamera(camera, animated: true)
                completion()
            }
        case "map#queryCameraPosition":
            if let camera = getCamera() {
                result(camera.toDict(mapView: mapView))
            } else {
                result(nil)
            }
        case "map#editGeoJsonSource":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let srcId = arguments["id"] as? String else { return }
            guard let srcData = arguments["data"] as? String else { return }
            guard let style = self.mapView.style else { return }

            var ret: Bool = false
            var reply: [String: Bool] = [:]
            if let data = srcData.data(using: String.Encoding.utf8) {
                let src = style.source(withIdentifier: srcId)
                if src != nil && src is MLNShapeSource {
                    let geojsonSrc = src as! MLNShapeSource
                    let geojsonData = try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)
                    if geojsonData != nil {
                        geojsonSrc.shape = geojsonData
                        ret = true
                    }
                }
            }

            reply["result"] = ret
            result(reply)
        case "map#editGeoJsonUrl":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let srcId = arguments["id"] as? String else { return }
            guard let srcUrl = arguments["url"] as? String else { return }
            guard let style = self.mapView.style else { return }

            var ret: Bool = false
            var reply: [String: Bool] = [:]
            let src = style.source(withIdentifier: srcId)
            if src != nil && src is MLNShapeSource {
                let geojsonSrc = src as! MLNShapeSource
                let geojsonUrl = URL(string: srcUrl)
                if geojsonUrl != nil {
                    geojsonSrc.url = geojsonUrl
                    ret = true
                }
            }

            reply["result"] = ret
            result(reply)
        case "map#setLayerFilter":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let layerId = arguments["id"] as? String else { return }
            guard let layerFilter = arguments["filter"] as? String else { return }
            guard let style = self.mapView.style else { return }

            var ret: Bool = false
            var reply: [String: Bool] = [:]
            let layer = style.layer(withIdentifier: layerId)
            if layer != nil {
                do {
                    if let data = layerFilter.data(using: .utf8) {
                        let jsonFilter = try JSONSerialization.jsonObject(with: data, options: [])
                        let predicate = NSPredicate(mglJSONObject: jsonFilter)
                        if let layer = layer as? MLNVectorStyleLayer {
                            layer.predicate = predicate
                            ret = true
                        }
                    }
                } catch {
                    print("Error parsing filter: \(error.localizedDescription)")
                }
            }

            reply["result"] = ret
            result(reply)
        case "map#getStyle":
            var reply: [String: Bool] = [:]
            reply["result"] = false
            result(reply)
        case "map#setCustomHeaders":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let headers = arguments["headers"] as? [String:String] else { return }
            guard let filter = arguments["filter"] as? [String] else { return }
            MapLibreCustomHeaders.setCustomHeaders(headers, filter: filter)
            result(nil)
        case "map#getCustomHeaders":
            result(MapLibreCustomHeaders.getCustomHeaders())
        case "map#getVisibleRegion":
            var reply = [String: NSObject]()
            let visibleRegion = mapView.visibleCoordinateBounds
            reply["sw"] = [visibleRegion.sw.latitude, visibleRegion.sw.longitude] as NSObject
            reply["ne"] = [visibleRegion.ne.latitude, visibleRegion.ne.longitude] as NSObject
            result(reply)
        case "map#toScreenLocation":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let latitude = arguments["latitude"] as? Double else { return }
            guard let longitude = arguments["longitude"] as? Double else { return }
            let latlng = CLLocationCoordinate2DMake(latitude, longitude)
            let returnVal = mapView.convert(latlng, toPointTo: mapView)
            var reply = [String: NSObject]()
            reply["x"] = returnVal.x as NSObject
            reply["y"] = returnVal.y as NSObject
            result(reply)
        case "map#toScreenLocationBatch":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let data = arguments["coordinates"] as? FlutterStandardTypedData else { return }
            let latLngs = data.data.withUnsafeBytes {
                Array(
                    UnsafeBufferPointer(
                        start: $0.baseAddress!.assumingMemoryBound(to: Double.self),
                        count: Int(data.elementCount)
                    )
                )
            }
            var reply: [Double] = Array(repeating: 0.0, count: latLngs.count)
            for i in stride(from: 0, to: latLngs.count, by: 2) {
                let coordinate = CLLocationCoordinate2DMake(latLngs[i], latLngs[i + 1])
                let returnVal = mapView.convert(coordinate, toPointTo: mapView)
                reply[i] = Double(returnVal.x)
                reply[i + 1] = Double(returnVal.y)
            }
            result(FlutterStandardTypedData(
                float64: Data(bytes: &reply, count: reply.count * 8)
            ))
        case "map#getMetersPerPixelAtLatitude":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            var reply = [String: NSObject]()
            guard let latitude = arguments["latitude"] as? Double else { return }
            let returnVal = mapView.metersPerPoint(atLatitude: latitude)
            reply["metersperpixel"] = returnVal as NSObject
            result(reply)
        case "map#toLatLng":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let x = arguments["x"] as? Double else { return }
            guard let y = arguments["y"] as? Double else { return }
            let screenPoint = CGPoint(x: x, y: y)
            let coordinates: CLLocationCoordinate2D = mapView.convert(
                screenPoint,
                toCoordinateFrom: mapView
            )
            var reply = [String: NSObject]()
            reply["latitude"] = coordinates.latitude as NSObject
            reply["longitude"] = coordinates.longitude as NSObject
            result(reply)
        case "camera#move":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }

            if let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) {
                mapView.setCamera(camera, animated: false)
            }
            result(nil)
        case "camera#animate":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }
            guard let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) else { return }


            let completion = {
                result(nil)
            }

            if let duration = arguments["duration"] as? TimeInterval {
                if let padding = Convert.parseLatLngBoundsPadding(cameraUpdate) {
                    mapView.fly(to: camera, edgePadding: padding, withDuration: duration / 1000, completionHandler: completion)
                } else {
                    mapView.fly(to: camera, withDuration: duration / 1000, completionHandler: completion)
                }
            } else {
                mapView.setCamera(camera, animated: true)
                completion()
            }
        case "symbolLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            guard let enableInteraction = arguments["enableInteraction"] as? Bool else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let sourceLayer = arguments["sourceLayer"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double
            let filter = arguments["filter"] as? String

            let addResult = addSymbolLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayerIdentifier: sourceLayer,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: properties
            )
            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "lineLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            guard let enableInteraction = arguments["enableInteraction"] as? Bool else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let sourceLayer = arguments["sourceLayer"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double
            let filter = arguments["filter"] as? String

            let addResult = addLineLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayerIdentifier: sourceLayer,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: properties
            )
            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "layer#setProperties":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }

            guard let layer = mapView.style?.layer(withIdentifier: layerId) else {
                result(FlutterError(
                    code: "LAYER_NOT_FOUND_ERROR",
                    message: "Layer " + layerId + "not found",
                    details: ""
                ))
                return
            }

            //switch depending on the runtime type of layer
            switch layer {
            case let lineLayer as MLNLineStyleLayer:
                LayerPropertyConverter.addLineProperties(lineLayer: lineLayer, properties: properties)
            case let fillLayer as MLNFillStyleLayer:
                LayerPropertyConverter.addFillProperties(fillLayer: fillLayer, properties: properties)
            case let circleLayer as MLNCircleStyleLayer:
                LayerPropertyConverter.addCircleProperties(circleLayer: circleLayer, properties: properties)
             case let symbolLayer as MLNSymbolStyleLayer:
                LayerPropertyConverter.addSymbolProperties(symbolLayer: symbolLayer, properties: properties)
            case let rasterLayer as MLNRasterStyleLayer:
                LayerPropertyConverter.addRasterProperties(rasterLayer: rasterLayer, properties: properties)
            case let hillshadeLayer as MLNHillshadeStyleLayer:
                LayerPropertyConverter.addHillshadeProperties(hillshadeLayer: hillshadeLayer, properties: properties)
            default:
                result(FlutterError(
                    code: "UNSUPPORTED_LAYER_TYPE",
                    message: "Layer type not supported",
                    details: ""
                ))
                return
            }

            result(nil)

        case "fillLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            guard let enableInteraction = arguments["enableInteraction"] as? Bool else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let sourceLayer = arguments["sourceLayer"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double
            let filter = arguments["filter"] as? String

            let addResult = addFillLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayerIdentifier: sourceLayer,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: properties
            )
            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "fillExtrusionLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            guard let enableInteraction = arguments["enableInteraction"] as? Bool else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let sourceLayer = arguments["sourceLayer"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double
            let filter = arguments["filter"] as? String

            let addResult = addFillExtrusionLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayerIdentifier: sourceLayer,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: properties
            )
            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "circleLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            guard let enableInteraction = arguments["enableInteraction"] as? Bool else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let sourceLayer = arguments["sourceLayer"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double
            let filter = arguments["filter"] as? String

            let addResult = addCircleLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayerIdentifier: sourceLayer,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: properties
            )
            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "hillshadeLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double

            let addResult = addHillshadeLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                properties: properties
            )

            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "heatmapLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double
            let addResult = addHeatmapLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                properties: properties
            )
            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "rasterLayer#add":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: String] else { return }
            let belowLayerId = arguments["belowLayerId"] as? String
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double
            let addResult = addRasterLayer(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                minimumZoomLevel: minzoom,
                maximumZoomLevel: maxzoom,
                properties: properties
            )
            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "style#addImage":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let name = arguments["name"] as? String else { return }
            // guard let length = arguments["length"] as? NSNumber else { return }
            guard let bytes = arguments["bytes"] as? FlutterStandardTypedData else { return }
            guard let sdf = arguments["sdf"] as? Bool else { return }
            guard let data = bytes.data as? Data else { return }
            guard let image = UIImage(data: data, scale: UIScreen.main.scale) else { return }
            if sdf {
                mapView.style?.setImage(image.withRenderingMode(.alwaysTemplate), forName: name)
            } else {
                mapView.style?.setImage(image, forName: name)
            }
            result(nil)

        case "style#addImageSource":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let imageSourceId = arguments["imageSourceId"] as? String else { return }
            guard let bytes = arguments["bytes"] as? FlutterStandardTypedData else { return }
            guard let data = bytes.data as? Data else { return }
            guard let image = UIImage(data: data) else { return }

            guard let coordinates = arguments["coordinates"] as? [[Double]] else { return }
            let quad = MLNCoordinateQuad(
                topLeft: CLLocationCoordinate2D(
                    latitude: coordinates[0][0],
                    longitude: coordinates[0][1]
                ),
                bottomLeft: CLLocationCoordinate2D(
                    latitude: coordinates[3][0],
                    longitude: coordinates[3][1]
                ),
                bottomRight: CLLocationCoordinate2D(
                    latitude: coordinates[2][0],
                    longitude: coordinates[2][1]
                ),
                topRight: CLLocationCoordinate2D(
                    latitude: coordinates[1][0],
                    longitude: coordinates[1][1]
                )
            )

            // Check for duplicateSource error
            if mapView.style?.source(withIdentifier: imageSourceId) != nil {
                result(FlutterError(
                    code: "duplicateSource",
                    message: "Source with imageSourceId \(imageSourceId) already exists",
                    details: "Can't add duplicate source with imageSourceId: \(imageSourceId)"
                ))
                return
            }

            let source = MLNImageSource(
                identifier: imageSourceId,
                coordinateQuad: quad,
                image: image
            )
            mapView.style?.addSource(source)

            result(nil)
        case "style#updateImageSource":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let imageSourceId = arguments["imageSourceId"] as? String else { return }
            guard let imageSource = mapView.style?
                .source(withIdentifier: imageSourceId) as? MLNImageSource else { return }
            let bytes = arguments["bytes"] as? FlutterStandardTypedData
            if bytes != nil {
                guard let data = bytes!.data as? Data else { return }
                guard let image = UIImage(data: data) else { return }
                imageSource.image = image
            }
            let coordinates = arguments["coordinates"] as? [[Double]]
            if coordinates != nil {
                let quad = MLNCoordinateQuad(
                    topLeft: CLLocationCoordinate2D(
                        latitude: coordinates![0][0],
                        longitude: coordinates![0][1]
                    ),
                    bottomLeft: CLLocationCoordinate2D(
                        latitude: coordinates![3][0],
                        longitude: coordinates![3][1]
                    ),
                    bottomRight: CLLocationCoordinate2D(
                        latitude: coordinates![2][0],
                        longitude: coordinates![2][1]
                    ),
                    topRight: CLLocationCoordinate2D(
                        latitude: coordinates![1][0],
                        longitude: coordinates![1][1]
                    )
                )
                imageSource.coordinates = quad
            }
            result(nil)
        case "style#removeSource":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let source = mapView.style?.source(withIdentifier: sourceId) else {
                result(nil)
                return
            }
            mapView.style?.removeSource(source)
            result(nil)
        case "style#addLayer":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let imageLayerId = arguments["imageLayerId"] as? String else { return }
            guard let imageSourceId = arguments["imageSourceId"] as? String else { return }
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double

            // Check for duplicateLayer error
            if (mapView.style?.layer(withIdentifier: imageLayerId)) != nil {
                result(FlutterError(
                    code: "duplicateLayer",
                    message: "Layer already exists",
                    details: "Can't add duplicate layer with imageLayerId: \(imageLayerId)"
                ))
                return
            }
            // Check for noSuchSource error
            guard let source = mapView.style?.source(withIdentifier: imageSourceId) else {
                result(FlutterError(
                    code: "noSuchSource",
                    message: "No source found with imageSourceId \(imageSourceId)",
                    details: "Can't add add layer for imageSourceId \(imageLayerId), as the source does not exist."
                ))
                return
            }

            let layer = MLNRasterStyleLayer(identifier: imageLayerId, source: source)

            if let minzoom = minzoom {
                layer.minimumZoomLevel = Float(minzoom)
            }

            if let maxzoom = maxzoom {
                layer.maximumZoomLevel = Float(maxzoom)
            }

            mapView.style?.addLayer(layer)
        case "style#addLayerBelow":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let imageLayerId = arguments["imageLayerId"] as? String else { return }
            guard let imageSourceId = arguments["imageSourceId"] as? String else { return }
            guard let belowLayerId = arguments["belowLayerId"] as? String else { return }
            let minzoom = arguments["minzoom"] as? Double
            let maxzoom = arguments["maxzoom"] as? Double

            // Check for duplicateLayer error
            if (mapView.style?.layer(withIdentifier: imageLayerId)) != nil {
                result(FlutterError(
                    code: "duplicateLayer",
                    message: "Layer already exists",
                    details: "Can't add duplicate layer with imageLayerId: \(imageLayerId)"
                ))
                return
            }
            // Check for noSuchSource error
            guard let source = mapView.style?.source(withIdentifier: imageSourceId) else {
                result(FlutterError(
                    code: "noSuchSource",
                    message: "No source found with imageSourceId \(imageSourceId)",
                    details: "Can't add add layer for imageSourceId \(imageLayerId), as the source does not exist."
                ))
                return
            }
            // Check for noSuchLayer error
            guard let belowLayer = mapView.style?.layer(withIdentifier: belowLayerId) else {
                result(FlutterError(
                    code: "noSuchLayer",
                    message: "No layer found with layerId \(belowLayerId)",
                    details: "Can't insert layer below layer with id \(belowLayerId), as no such layer exists."
                ))
                return
            }

            let layer = MLNRasterStyleLayer(identifier: imageLayerId, source: source)

            if let minzoom = minzoom {
                layer.minimumZoomLevel = Float(minzoom)
            }

            if let maxzoom = maxzoom {
                layer.maximumZoomLevel = Float(maxzoom)
            }
            mapView.style?.insertLayer(layer, below: belowLayer)
            result(nil)

        case "style#removeLayer":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let layer = mapView.style?.layer(withIdentifier: layerId) else {
                result(MethodCallError.layerNotFound(
                   layerId: layerId
                ).flutterError)
                return
            }
            interactiveFeatureLayerIds.remove(layerId)
            mapView.style?.removeLayer(layer)
            result(nil)

        case "map#setCameraBounds":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let west = arguments["west"] as? Double else { return }
            guard let north = arguments["north"] as? Double else { return }
            guard let south = arguments["south"] as? Double else { return }
            guard let east = arguments["east"] as? Double else { return }
            guard let padding = arguments["padding"] as? CGFloat else { return }

            let southwest = CLLocationCoordinate2D(latitude: south, longitude: west)
            let northeast = CLLocationCoordinate2D(latitude: north, longitude: east)
            let bounds = MLNCoordinateBounds(sw: southwest, ne: northeast)
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: padding,
                left: padding, bottom: padding, right: padding) , animated: true)
            result(nil)

        case "style#setFilter":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let filter = arguments["filter"] as? String else { return }
            guard let layer = mapView.style?.layer(withIdentifier: layerId) else {
                result(MethodCallError.layerNotFound(
                   layerId: layerId
                ).flutterError)
                return
            }
            switch setFilter(layer, filter) {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "source#addGeoJson":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let geojson = arguments["geojson"] as? String else { return }
            let addResult = addSourceGeojson(sourceId: sourceId, geojson: geojson)

            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "style#addSource":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let properties = arguments["properties"] as? [String: Any] else { return }
            let addResult = addSource(sourceId: sourceId, properties: properties)

            switch addResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "source#setGeoJson":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let geojson = arguments["geojson"] as? String else { return }
            let setResult = setSource(sourceId: sourceId, geojson: geojson)

            switch setResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "source#setFeature":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            guard let geojson = arguments["geojsonFeature"] as? String else { return }
            let setResult = setFeature(sourceId: sourceId, geojsonFeature: geojson)

            switch setResult {
            case .success: result(nil)
            case let .failure(error): result(error.flutterError)
            }

        case "layer#setVisibility":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let layerId = arguments["layerId"] as? String else { return }
            guard let visible = arguments["visible"] as? Bool else { return }
            guard let layer = mapView.style?.layer(withIdentifier: layerId) else {
                result(MethodCallError.layerNotFound(
                   layerId: layerId
                ).flutterError)
                return
            }
            layer.isVisible = visible
            result(nil)

        case "map#querySourceFeatures":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }

            var sourceLayerId = Set<String>()
            if let layerId = arguments["sourceLayerId"] as? String {
                sourceLayerId.insert(layerId)
            }
            var filterExpression: NSPredicate?
            if let filter = arguments["filter"] as? [Any] {
                filterExpression = NSPredicate(mglJSONObject: filter)
            }

            var reply = [String: NSObject]()
            var features: [MLNFeature] = []

            guard let style = mapView.style else { return }
            if let source = style.source(withIdentifier: sourceId) {
                if let vectorSource = source as? MLNVectorTileSource {
                    features = vectorSource.features(sourceLayerIdentifiers: sourceLayerId, predicate: filterExpression)
                } else if let shapeSource = source as? MLNShapeSource {
                    features = shapeSource.features(matching: filterExpression)
                }
            }

            var featuresJson = [String]()
            for feature in features {
                let dictionary = feature.geoJSONDictionary()
                if let theJSONData = try? JSONSerialization.data(
                    withJSONObject: dictionary,
                    options: []
                ),
                    let theJSONText = String(data: theJSONData, encoding: .utf8)
                {
                    featuresJson.append(theJSONText)
                }
            }
            reply["features"] = featuresJson as NSObject
            result(reply)

        case "style#getLayerIds":
            var layerIds = [String]()

            guard let style = mapView.style else { return }

            style.layers.forEach { layer in layerIds.append(layer.identifier) }

            var reply = [String: NSObject]()
            reply["layers"] = layerIds as NSObject
            result(reply)

        case "style#getSourceIds":
            var sourceIds = [String]()

            guard let style = mapView.style else { return }

            style.sources.forEach { source in sourceIds.append(source.identifier) }

            var reply = [String: NSObject]()
            reply["sources"] = sourceIds as NSObject
            result(reply)

        case "style#getFilter":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let layerId = arguments["layerId"] as? String else { return }

            guard let style = mapView.style else { return }
            guard let layer = style.layer(withIdentifier: layerId) else { return }

            var currentLayerFilter : String = ""
            if let vectorLayer = layer as? MLNVectorStyleLayer {
                if let layerFilter = vectorLayer.predicate {

                    let jsonExpression = layerFilter.mgl_jsonExpressionObject
                    if let data = try? JSONSerialization.data(withJSONObject: jsonExpression, options: []) {
                        currentLayerFilter = String(data: data, encoding: String.Encoding.utf8) ?? ""
                    }
                }
            } else {
                result(MethodCallError.invalidLayerType(
                    details: "Layer '\(layer.identifier)' does not support filtering."
                ).flutterError)
                return;
            }

            var reply = [String: NSObject]()
            reply["filter"] = currentLayerFilter as NSObject
            result(reply)

        case "style#setStyle":
            if let arguments = methodCall.arguments as? [String: Any] {
              if let style = arguments["style"] as? String {
                setStyleString(styleString: style)
                result(nil)
              } else {
                // Error for missing style key in argument
                result(
                    FlutterError(
                        code: "invalidStyleString",
                        message: "Missing style key in arguments",
                        details: nil
                    )
                )
              }
            } else {
              // Error for invalid arguments type
              result(
                  FlutterError(
                      code: "invalidArgumentsType",
                      message: "Arguments not of type [String: Any]",
                      details: nil
                  )
              )
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func loadIconImage(name: String) -> UIImage? {
        // Build up the full path of the asset.
        // First find the last '/' ans split the image name in the asset directory and the image file name.
        if let range = name.range(of: "/", options: [.backwards]) {
            let directory = String(name[..<range.lowerBound])
            let assetPath = registrar.lookupKey(forAsset: "\(directory)/")
            let fileName = String(name[range.upperBound...])
            // If we can load the image from file then add it to the map.
            return UIImage.loadFromFile(
                imagePath: assetPath,
                imageName: fileName
            )
        }
        return nil
    }

    private func addIconImageToMap(iconImageName: String) {
        // Check if the image has already been added to the map.
        if mapView.style?.image(forName: iconImageName) == nil {
            if let imageFromAsset = loadIconImage(name: iconImageName) {
                mapView.style?.setImage(imageFromAsset, forName: iconImageName)
            }
        }
    }

    private func updateMyLocationEnabled() {
        mapView.showsUserLocation = myLocationEnabled
    }

    private func getCamera() -> MLNMapCamera? {
        return trackCameraPosition ? mapView.camera : nil
    }

    private func setMapLanguage(language: String) {
        self.mapView.setMapLanguage(language)
    }

    /*
     *  Scan layers from top to bottom and return the first matching feature
     */
    private func firstFeatureOnLayers(at: CGPoint) -> (feature: MLNFeature?, layerId: String?) {
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

        for layer in clickableLayers.reversed() {
            let features = mapView.visibleFeatures(
                at: at,
                styleLayerIdentifiers: [layer.identifier]
            )
            if let feature = features.first {
                return (feature, layer.identifier)
            }
        }
        return (nil, nil)
    }

    /*
     *  UITapGestureRecognizer
     *  On tap invoke the map#onMapClick callback.
     */
    @IBAction func handleMapTap(sender: UITapGestureRecognizer) {
        // Get the CGPoint where the user tapped.
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

        let result = firstFeatureOnLayers(at: point)
        if let feature = result.feature {
            channel?.invokeMethod("feature#onTap", arguments: [
                        "id": feature.identifier,
                        "x": point.x,
                        "y": point.y,
                        "lng": coordinate.longitude,
                        "lat": coordinate.latitude,
                        "layerId": result.layerId,
            ])
            // Fire map#onMapClick only if featureTapsTriggersMapClick is true
            if featureTapsTriggersMapClick {
                channel?.invokeMethod("map#onMapClick", arguments: [
                    "x": point.x,
                    "y": point.y,
                    "lng": coordinate.longitude,
                    "lat": coordinate.latitude,
                ])
            }
        } else {
            // Always fire map#onMapClick when no feature is tapped
            channel?.invokeMethod("map#onMapClick", arguments: [
                "x": point.x,
                "y": point.y,
                "lng": coordinate.longitude,
                "lat": coordinate.latitude,
            ])
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
            channel?.invokeMethod("feature#onDrag", arguments: [
                "id": id,
                "x": point.x,
                "y": point.y,
                "originLng": origin.longitude,
                "originLat": origin.latitude,
                "currentLng": coordinate.longitude,
                "currentLat": coordinate.latitude,
                "eventType": eventType,
                "deltaLng": coordinate.longitude - previous.longitude,
                "deltaLat": coordinate.latitude - previous.latitude,
            ])
        }
    }

    @IBAction func handleMapPan(sender: UIPanGestureRecognizer) {
        let began = sender.state == UIGestureRecognizer.State.began
        let end = sender.state == UIGestureRecognizer.State.ended
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

        if dragFeature == nil, began, sender.numberOfTouches == 1 {
            let result = firstFeatureOnLayers(at: point)
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
        if end, dragFeature != nil {
            mapView.allowsScrolling = true
            let eventType = "end"
            invokeFeatureDrag(point, coordinate, eventType)
            dragFeature = nil
            originDragCoordinate = nil
            previousDragCoordinate = nil
        }

        if !began, !end, dragFeature != nil {
            let eventType = "drag"
            invokeFeatureDrag(point, coordinate, eventType)
            previousDragCoordinate = coordinate
        }
    }

    /*
     *  UILongPressGestureRecognizer
     *  After a long press invoke the map#onMapLongClick callback.
     */
    @IBAction func handleMapLongPress(sender: UILongPressGestureRecognizer) {
        // Fire when the long press starts
        if sender.state == .began {
            // Get the CGPoint where the user tapped.
            let point = sender.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            channel?.invokeMethod("map#onMapLongClick", arguments: [
                "x": point.x,
                "y": point.y,
                "lng": coordinate.longitude,
                "lat": coordinate.latitude,
            ])
        }
    }

    /* /*
     * Override the attribution button's click target to handle the event locally.
     * Called if the application supplies an onAttributionClick handler.
     */
    func setupAttribution(_ mapView: MLNMapView) {
        mapView.attributionButton.removeTarget(
            mapView,
            action: #selector(mapView.showAttribution),
            for: .touchUpInside
        )
        mapView.attributionButton.addTarget(
            self,
            action: #selector(showAttribution),
            for: UIControl.Event.touchUpInside
        )
    }

    /*
     * Custom click handler for the attribution button. This callback is bound when
     * the application specifies an onAttributionClick handler.
     */
    @objc func showAttribution() {
        channel?.invokeMethod("map#onAttributionClick", arguments: [])
    } */

    /*
     *  MLNMapViewDelegate
     */
    func mapView(_ mapView: MLNMapView, didFinishLoading _: MLNStyle) {
        isMapReady = true
        updateMyLocationEnabled()

        if let initialTilt = initialTilt {
            let camera = mapView.camera
            camera.pitch = initialTilt
            mapView.setCamera(camera, animated: false)
        }

        addedShapesByLayer.removeAll()
        interactiveFeatureLayerIds.removeAll()

        mapReadyResult?(nil)

        // On first launch we only call map#onStyleLoaded if map#waitForMap has already been called
        if !isFirstStyleLoad || mapReadyResult != nil {
            isFirstStyleLoad = false

            if let channel = channel {
                onStyleLoadedCalled = true
                // Defer the callback to the next run loop iteration to avoid race conditions
                // where the map's internal state is not fully ready for operations like camera animations
                DispatchQueue.main.async {
                    channel.invokeMethod("map#onStyleLoaded", arguments: nil)
                }
            }
        }
    }

    // handle missing images
    func mapView(_: MLNMapView, didFailToLoadImage name: String) -> UIImage? {
        return loadIconImage(name: name)
    }

    func mapView(_: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
        if let channel = channel, let userLocation = userLocation,
           let location = userLocation.location
        {
            channel.invokeMethod("map#onUserLocationUpdated", arguments: [
                "userLocation": location.toDict(),
                "heading": userLocation.heading?.toDict(),
            ])
        }
    }

    func mapView(_: MLNMapView, didChange mode: MLNUserTrackingMode, animated _: Bool) {
        if let channel = channel {
            channel.invokeMethod("map#onCameraTrackingChanged", arguments: ["mode": mode.rawValue])
            if mode == .none {
                channel.invokeMethod("map#onCameraTrackingDismissed", arguments: [])
            }
        }
    }

    private func validateBeforeLayerAdd(
        sourceId: String,
        layerId: String
    ) -> Result<(MLNStyle, MLNSource), MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotFound)
        }
        guard let source = style.source(withIdentifier: sourceId) else {
            return .failure(.sourceNotFound(sourceId: sourceId))
        }
        guard style.layer(withIdentifier: layerId) == nil else {
            return .failure(.layerAlreadyExists(layerId: layerId))
        }
        return .success((style, source))
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
        properties: [String: String]
    ) -> Result<Void, MethodCallError> {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNSymbolStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addSymbolProperties(
                symbolLayer: layer,
                properties: properties
            )
            if let sourceLayerIdentifier = sourceLayerIdentifier {
                layer.sourceLayerIdentifier = sourceLayerIdentifier
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
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            if enableInteraction {
                interactiveFeatureLayerIds.insert(layerId)
            }
            return .success(())
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
        properties: [String: String]
    ) -> Result<Void, MethodCallError> {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNLineStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addLineProperties(lineLayer: layer, properties: properties)
            if let sourceLayerIdentifier = sourceLayerIdentifier {
                layer.sourceLayerIdentifier = sourceLayerIdentifier
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
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            if enableInteraction {
                interactiveFeatureLayerIds.insert(layerId)
            }
            return .success(())
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
        properties: [String: String]
    ) -> Result<Void, MethodCallError> {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNFillStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addFillProperties(fillLayer: layer, properties: properties)
            if let sourceLayerIdentifier = sourceLayerIdentifier {
                layer.sourceLayerIdentifier = sourceLayerIdentifier
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
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            if enableInteraction {
                interactiveFeatureLayerIds.insert(layerId)
            }
            return .success(())
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
        properties: [String: String]
    ) -> Result<Void, MethodCallError> {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNFillExtrusionStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addFillExtrusionProperties(
                fillExtrusionLayer: layer,
                properties: properties
            )
            if let sourceLayerIdentifier = sourceLayerIdentifier {
                layer.sourceLayerIdentifier = sourceLayerIdentifier
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
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            if enableInteraction {
                interactiveFeatureLayerIds.insert(layerId)
            }
            return .success(())
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
        properties: [String: String]
    ) -> Result<Void, MethodCallError> {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNCircleStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addCircleProperties(
                circleLayer: layer,
                properties: properties
            )
            if let sourceLayerIdentifier = sourceLayerIdentifier {
                layer.sourceLayerIdentifier = sourceLayerIdentifier
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
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            if enableInteraction {
                interactiveFeatureLayerIds.insert(layerId)
            }
            return .success(())
        }
    }

    func setFilter(_ layer: MLNStyleLayer, _ filter: String) -> Result<Void, MethodCallError> {
        do {
            let filter = try JSONSerialization.jsonObject(
                with: filter.data(using: .utf8)!,
                options: .fragmentsAllowed
            )
            if filter is NSNull {
                return .success(())
            }
            let predicate = NSPredicate(mglJSONObject: filter)
            if let layer = layer as? MLNVectorStyleLayer {
                layer.predicate = predicate
            } else {
                return .failure(MethodCallError.invalidLayerType(
                    details: "Layer '\(layer.identifier)' does not support filtering."
                ))
            }
            return .success(())
        } catch {
            return .failure(MethodCallError.invalidExpression)
        }
    }

    func addHillshadeLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        properties: [String: String]
    ) -> Result<Void, MethodCallError> {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNHillshadeStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addHillshadeProperties(
                hillshadeLayer: layer,
                properties: properties
            )
            if let minimumZoomLevel = minimumZoomLevel {
                layer.minimumZoomLevel = Float(minimumZoomLevel)
            }
            if let maximumZoomLevel = maximumZoomLevel {
                layer.maximumZoomLevel = Float(maximumZoomLevel)
            }
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            return .success(())
        }
    }

    func addHeatmapLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        properties: [String: String]
    ) -> Result<Void, MethodCallError> {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNHeatmapStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addHeatmapProperties(
                heatmapLayer: layer,
                properties: properties
            )
            if let minimumZoomLevel = minimumZoomLevel {
                layer.minimumZoomLevel = Float(minimumZoomLevel)
            }
            if let maximumZoomLevel = maximumZoomLevel {
                layer.maximumZoomLevel = Float(maximumZoomLevel)
            }
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            return .success(())
        }
    }

    func addRasterLayer(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minimumZoomLevel: Double?,
        maximumZoomLevel: Double?,
        properties: [String: String]
    )  -> Result<Void, MethodCallError>  {
        switch validateBeforeLayerAdd(sourceId: sourceId, layerId: layerId) {
        case .failure(let error):
            return .failure(error)
        case .success(let (style, source)):
            let layer = MLNRasterStyleLayer(identifier: layerId, source: source)
            LayerPropertyConverter.addRasterProperties(
                rasterLayer: layer,
                properties: properties
            )
            if let minimumZoomLevel = minimumZoomLevel {
                layer.minimumZoomLevel = Float(minimumZoomLevel)
            }
            if let maximumZoomLevel = maximumZoomLevel {
                layer.maximumZoomLevel = Float(maximumZoomLevel)
            }
            if let id = belowLayerId, let belowLayer = style.layer(withIdentifier: id) {
                style.insertLayer(layer, below: belowLayer)
            } else {
                style.addLayer(layer)
            }
            return .success(())
        }
    }

    func addSource(sourceId: String, properties: [String: Any]) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotFound)
        }
        guard style.source(withIdentifier: sourceId) == nil else {
            return .failure(.sourceAlreadyExists(sourceId: sourceId))
        }
        guard let type = properties["type"] as? String else {
            return .failure(.invalidSourceType(
                details: "Source '\(sourceId)' does not have a type."
            ))
        }

        var source: MLNSource?
        switch type {
        case "vector":
            source = SourcePropertyConverter.buildVectorTileSource(
                identifier: sourceId,
                properties: properties
            )
        case "raster":
            source = SourcePropertyConverter.buildRasterTileSource(
                identifier: sourceId,
                properties: properties
            )
        case "raster-dem":
            source = SourcePropertyConverter.buildRasterDemSource(
                identifier: sourceId,
                properties: properties
            )
        case "image":
            source = SourcePropertyConverter.buildImageSource(
                identifier: sourceId,
                properties: properties
            )
        case "geojson":
            source = SourcePropertyConverter.buildShapeSource(
                identifier: sourceId,
                properties: properties
            )
        default:
            // unsupported source type
            source = nil
        }
        if let source = source {
            style.addSource(source)
            return .success(())
        }
        return .failure(.invalidSourceType(
            details: "Source '\(sourceId)' does not support type '\(type)'."
        ))

    }

    func mapViewDidBecomeIdle(_: MLNMapView) {
        if let channel = channel {
            channel.invokeMethod("map#onIdle", arguments: [])
        }
    }

    func mapView(_: MLNMapView, regionWillChangeAnimated _: Bool) {
        if let channel = channel {
            channel.invokeMethod("camera#onMoveStarted", arguments: [])
        }
    }

    func mapViewRegionIsChanging(_ mapView: MLNMapView) {
        if !trackCameraPosition { return }
        if let channel = channel {
            channel.invokeMethod("camera#onMove", arguments: [
                "position": getCamera()?.toDict(mapView: mapView),
            ])
        }
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        let arguments = trackCameraPosition ? [
            "position": getCamera()?.toDict(mapView: mapView)
        ] : [:]
        if let channel = channel {
            channel.invokeMethod("camera#onIdle", arguments: arguments)
        }
    }

    func addSourceGeojson(sourceId: String, geojson: String) -> Result<Void, MethodCallError> {
        do{
            guard let style = mapView.style else {
                return .failure(.styleNotFound)
            }
            guard style.source(withIdentifier: sourceId) == nil else {
                return .failure(.sourceAlreadyExists(sourceId: sourceId))
            }

            let parsed = try MLNShape(
                data: geojson.data(using: .utf8)!,
                encoding: String.Encoding.utf8.rawValue
            )
            let source = MLNShapeSource(identifier: sourceId, shape: parsed, options: [:])
            addedShapesByLayer[sourceId] = parsed
            style.addSource(source)
            return .success(())
        } catch {
            return .failure(.geojsonParseError(sourceId: sourceId))
        }
    }

    func setSource(sourceId: String, geojson: String) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotFound)
        }

        do{
            let parsed = try MLNShape(
                data: geojson.data(using: .utf8)!,
                encoding: String.Encoding.utf8.rawValue
            )
            guard let source = style.source(withIdentifier: sourceId) as? MLNShapeSource else {
                return .failure(.sourceNotFound(sourceId: sourceId))
            }
            addedShapesByLayer[sourceId] = parsed
            source.shape = parsed
            return .success(())
        }catch{
            return .failure(.geojsonParseError(sourceId: sourceId))
        }

    }


    func setFeature(sourceId: String, geojsonFeature: String) -> Result<Void, MethodCallError> {
        guard let style = mapView.style else {
            return .failure(.styleNotFound)
        }
        do {
            let newShape = try MLNShape(
                data: geojsonFeature.data(using: .utf8)!,
                encoding: String.Encoding.utf8.rawValue
            )
            guard let source = style.source(withIdentifier: sourceId) as? MLNShapeSource else {
                return .failure(.sourceNotFound(sourceId: sourceId))
            }
            if let shape = addedShapesByLayer[sourceId] as? MLNShapeCollectionFeature,
               let feature = newShape as? MLNShape & MLNFeature
            {
                if let index = shape.shapes
                    .firstIndex(where: {
                        if let id = $0.identifier as? String,
                           let featureId = feature.identifier as? String
                        { return id == featureId }

                        if let id = $0.identifier as? NSNumber,
                           let featureId = feature.identifier as? NSNumber
                        { return id == featureId }
                        return false
                    })
                {
                    var shapes = shape.shapes
                    shapes[index] = feature

                    source.shape = MLNShapeCollectionFeature(shapes: shapes)
                }

                addedShapesByLayer[sourceId] = source.shape
                return .success(())
            }
            return .failure(.genericError(details: "Failed to set feature for sourceId \(sourceId)"))

        } catch {
            return .failure(.geojsonParseError(sourceId: sourceId))
        }
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
        
        if Self.styleStringIsJSON(styleString) {
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

    func setTiltGesturesEnabled(tiltGesturesEnabled: Bool) {
        mapView.allowsTilting = tiltGesturesEnabled
    }

    func setTrackCameraPosition(trackCameraPosition: Bool) {
        self.trackCameraPosition = trackCameraPosition
    }

    func setZoomGesturesEnabled(zoomGesturesEnabled: Bool) {
        mapView.allowsZooming = zoomGesturesEnabled
    }

    func setMyLocationEnabled(myLocationEnabled: Bool) {
        if self.myLocationEnabled == myLocationEnabled {
            return
        }
        self.myLocationEnabled = myLocationEnabled
        updateMyLocationEnabled()
    }

    func setMyLocationTrackingMode(myLocationTrackingMode: MLNUserTrackingMode) {
        mapView.userTrackingMode = myLocationTrackingMode
    }

    func setMyLocationRenderMode(myLocationRenderMode: MyLocationRenderMode) {
        switch myLocationRenderMode {
        case .Normal:
            mapView.showsUserHeadingIndicator = false
        case .Compass:
            mapView.showsUserHeadingIndicator = true
        case .Gps:
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

    func setAttributionButtonMargins(x: Double, y: Double) {
        mapView.attributionButtonMargins = CGPoint(x: x, y: y)
    }

    func setAttributionButtonPosition(position: MLNOrnamentPosition) {
        mapView.attributionButtonPosition = position
    }

    func setFeatureTapsTriggersMapClick(triggers: Bool) {
        featureTapsTriggersMapClick = triggers
    }
}

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
