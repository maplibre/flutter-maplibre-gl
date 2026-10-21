import MapLibre

class Convert {
    /// Applies the options that are set. A nil option is left as it is: at
    /// creation Dart leaves out what keeps the platform default, and in
    /// `mapUpdate` it sends only what changed.
    class func interpretMapLibreMapOptions(
        options: PgMapOptions,
        delegate: MapLibreMapOptionsSink
    ) {
        if let cameraTargetBounds = options.cameraTargetBounds {
            // Nil bounds lift the restriction.
            delegate.setCameraTargetBounds(bounds: cameraTargetBounds.bounds?.coordinateBounds)
        }
        if let compassEnabled = options.compassEnabled {
            delegate.setCompassEnabled(compassEnabled: compassEnabled)
        }
        if let minMaxZoomPreference = options.minMaxZoomPreference {
            // A nil end leaves that side unbounded.
            delegate.setMinMaxZoomPreference(
                min: minMaxZoomPreference.minZoom,
                max: minMaxZoomPreference.maxZoom
            )
        }
        if let styleString = options.styleString {
            delegate.setStyleString(styleString: styleString)
        }
        // Set before myLocationEnabled so the manual location manager is wired
        // in before `showsUserLocation` is first enabled (SDK ordering rule).
        if let locationSource = options.locationSource {
            delegate.setLocationSource(source: locationSource)
        }
        if let rotateGesturesEnabled = options.rotateGesturesEnabled {
            delegate.setRotateGesturesEnabled(rotateGesturesEnabled: rotateGesturesEnabled)
        }
        if let scrollGesturesEnabled = options.scrollGesturesEnabled {
            delegate.setScrollGesturesEnabled(scrollGesturesEnabled: scrollGesturesEnabled)
        }
        if let tiltGesturesEnabled = options.tiltGesturesEnabled {
            delegate.setTiltGesturesEnabled(tiltGesturesEnabled: tiltGesturesEnabled)
        }
        if let hapticFeedbackEnabled = options.hapticFeedbackEnabled {
            delegate.setHapticFeedbackEnabled(hapticFeedbackEnabled: hapticFeedbackEnabled)
        }
        if let trackCameraPosition = options.trackCameraPosition {
            delegate.setTrackCameraPosition(trackCameraPosition: trackCameraPosition)
        }
        if let zoomGesturesEnabled = options.zoomGesturesEnabled {
            delegate.setZoomGesturesEnabled(zoomGesturesEnabled: zoomGesturesEnabled)
        }
        if let doubleClickZoomEnabled = options.doubleClickZoomEnabled {
            delegate.setDoubleClickZoomEnabled(doubleClickZoomEnabled: doubleClickZoomEnabled)
        }
        if let panInertia = options.panInertia {
            delegate.setPanInertia(panInertia: panInertia)
        }
        if let myLocationEnabled = options.myLocationEnabled {
            delegate.setMyLocationEnabled(myLocationEnabled: myLocationEnabled)
        }
        // The raw values are those of MLNUserTrackingMode.
        if let myLocationTrackingMode = options.myLocationTrackingMode,
           let trackingMode = MLNUserTrackingMode(rawValue: UInt(myLocationTrackingMode.rawValue))
        {
            delegate.setMyLocationTrackingMode(myLocationTrackingMode: trackingMode)
        }
        if let myLocationRenderMode = options.myLocationRenderMode {
            delegate.setMyLocationRenderMode(myLocationRenderMode: myLocationRenderMode)
        }
        if let myLocationStyle = options.myLocationStyle {
            delegate.setMyLocationStyle(style: LocationPuckStyle(myLocationStyle))
        }
        if let logoEnabled = options.logoEnabled {
            delegate.setLogoEnabled(logoEnabled: logoEnabled)
        }
        if let position = ornamentPosition(options.logoViewPosition) {
            delegate.setLogoViewPosition(position: position)
        }
        if let logoViewMargins = options.logoViewMargins {
            delegate.setLogoViewMargins(x: logoViewMargins.x, y: logoViewMargins.y)
        }
        if let position = ornamentPosition(options.compassViewPosition) {
            delegate.setCompassViewPosition(position: position)
        }
        if let compassViewMargins = options.compassViewMargins {
            delegate.setCompassViewMargins(x: compassViewMargins.x, y: compassViewMargins.y)
        }
        if let attributionEnabled = options.attributionEnabled {
            delegate.setAttributionEnabled(attributionEnabled: attributionEnabled)
        }
        if let attributionButtonMargins = options.attributionButtonMargins {
            delegate.setAttributionButtonMargins(
                x: attributionButtonMargins.x,
                y: attributionButtonMargins.y
            )
        }
        if let position = ornamentPosition(options.attributionButtonPosition) {
            delegate.setAttributionButtonPosition(position: position)
        }
        if let attributionButtonColor = options.attributionButtonColor {
            delegate.setAttributionButtonColor(color: Int(attributionButtonColor))
        }
        if let featureTapsTriggersMapClick = options.featureTapsTriggersMapClick {
            delegate.setFeatureTapsTriggersMapClick(triggers: featureTapsTriggersMapClick)
        }
        if let enabled = options.symbolPlacementTransitionsEnabled {
            delegate.setSymbolPlacementTransitionsEnabled(enabled: enabled)
        }
        // Dart fills the iOS fields only.
        if let locationEngineProperties = options.locationEngineProperties {
            delegate.setLocationEngineProperties(
                enableHighAccuracy: locationEngineProperties.enableHighAccuracy ?? false,
                distanceFilter: Double(locationEngineProperties.displacement ?? 0),
                intervalMs: Int(locationEngineProperties.intervalMs ?? 0),
                pulseWindowMs: locationEngineProperties.pulseWindowMs.map { Int($0) }
                    ?? MapLibreMapController.defaultPulseWindowMs
            )
        }
    }

    /// The SDK position of an ornament. The raw values are those of
    /// MLNOrnamentPosition.
    private class func ornamentPosition(_ position: PgOrnamentPosition?) -> MLNOrnamentPosition? {
        return position.flatMap { MLNOrnamentPosition(rawValue: UInt($0.rawValue)) }
    }

    class func parseLatLngBoundsPadding(_ cameraUpdate: [Any]) -> UIEdgeInsets? {
        guard let methodName = cameraUpdate[0] as? String else { return nil }
        
        if(methodName != "newLatLngBounds") {
            return nil
        }
        
        guard let paddingLeft = cameraUpdate[2] as? CGFloat else { return nil }
        guard let paddingTop = cameraUpdate[3] as? CGFloat else { return nil }
        guard let paddingRight = cameraUpdate[4] as? CGFloat else { return nil }
        guard let paddingBottom = cameraUpdate[5] as? CGFloat else { return nil }
        
        return UIEdgeInsets(top: paddingTop, left: paddingLeft, bottom: paddingBottom, right: paddingRight)
    }

    class func parseCameraUpdate(cameraUpdate: [Any], mapView: MLNMapView) -> MLNMapCamera? {
        guard let type = cameraUpdate[0] as? String else { return nil }
        switch type {
        case "newCameraPosition":
            guard let cameraPosition = cameraUpdate[1] as? [String: Any] else { return nil }
            return MLNMapCamera.fromDict(cameraPosition, mapView: mapView)
        case "newLatLng":
            guard let coordinate = cameraUpdate[1] as? [Double] else { return nil }
            return cameraLooking(
                at: CLLocationCoordinate2D.fromArray(coordinate),
                zoom: getZoom(mapView: mapView),
                mapView: mapView
            )
        case "newLatLngBounds":
            guard let bounds = cameraUpdate[1] as? [[Double]] else { return nil }
            let padding = parseLatLngBoundsPadding(cameraUpdate) ?? .zero
            let fit = mapView.cameraThatFitsCoordinateBounds(
                MLNCoordinateBounds.fromArray(bounds),
                edgePadding: padding
            )
            return cameraFitting(fit, padding: padding, mapView: mapView)
        case "newLatLngZoom":
            guard let coordinate = cameraUpdate[1] as? [Double] else { return nil }
            guard let zoom = cameraUpdate[2] as? Double else { return nil }
            return cameraLooking(
                at: CLLocationCoordinate2D.fromArray(coordinate),
                zoom: zoom,
                mapView: mapView
            )
        case "scrollBy":
            guard let x = cameraUpdate[1] as? CGFloat else { return nil }
            guard let y = cameraUpdate[2] as? CGFloat else { return nil }
            let camera = mapView.camera
            let mapPoint = mapView.convert(camera.centerCoordinate, toPointTo: mapView)
            let movedPoint = CGPoint(x: mapPoint.x + x, y: mapPoint.y + y)
            let center = mapView.convert(movedPoint, toCoordinateFrom: mapView)
            return cameraLooking(at: center, zoom: getZoom(mapView: mapView), mapView: mapView)
        case "zoomBy":
            guard let zoomBy = cameraUpdate[1] as? Double else { return nil }
            let zoom = getZoom(mapView: mapView) + zoomBy
            if cameraUpdate.count == 2 {
                let camera = mapView.camera
                camera.altitude = getAltitude(zoom: zoom, mapView: mapView)
                return camera
            } else {
                guard let point = cameraUpdate[2] as? [CGFloat],
                      point.count == 2 else { return nil }
                // Keeps the point under the focus where it is on screen rather
                // than recentring on it: the view center moves toward the focus
                // by the share of the distance the zoom takes away.
                let focus = CGPoint(x: point[0], y: point[1])
                let centerPoint = mapView.convert(mapView.camera.centerCoordinate, toPointTo: mapView)
                let scale = CGFloat(pow(2, -zoomBy))
                let movedPoint = CGPoint(
                    x: focus.x + (centerPoint.x - focus.x) * scale,
                    y: focus.y + (centerPoint.y - focus.y) * scale
                )
                let center = mapView.convert(movedPoint, toCoordinateFrom: mapView)
                return cameraLooking(at: center, zoom: zoom, mapView: mapView)
            }
        case "zoomIn":
            let camera = mapView.camera
            let zoom = getZoom(mapView: mapView)
            let altitude = getAltitude(zoom: zoom + 1, mapView: mapView)
            camera.altitude = altitude
            return camera
        case "zoomOut":
            let camera = mapView.camera
            let zoom = getZoom(mapView: mapView)
            let altitude = getAltitude(zoom: zoom - 1, mapView: mapView)
            camera.altitude = altitude
            return camera
        case "zoomTo":
            guard let zoom = cameraUpdate[1] as? Double else { return nil }
            let camera = mapView.camera
            let altitude = getAltitude(zoom: zoom, mapView: mapView)
            camera.altitude = altitude
            return camera
        case "bearingTo":
            guard let bearing = cameraUpdate[1] as? Double else { return nil }
            let camera = mapView.camera
            camera.heading = bearing
            return camera
        case "tiltTo":
            guard let tilt = cameraUpdate[1] as? CGFloat else { return nil }
            // The zoom comes from the altitude together with the pitch, so the
            // same altitude at another pitch is another zoom level. Read the zoom
            // first and work the altitude out again for the new pitch, so tilting
            // keeps the zoom as on Android and web.
            let zoom = getZoom(mapView: mapView)
            let camera = mapView.camera
            camera.pitch = tilt
            camera.altitude = MLNAltitudeForZoomLevel(
                zoom,
                camera.pitch,
                camera.centerCoordinate.latitude,
                mapView.frame.size
            )
            return camera
        default:
            print("\(type) not implemented!")
        }
        return nil
    }

    class func getZoom(mapView: MLNMapView) -> Double {
        return MLNZoomLevelForAltitude(
            mapView.camera.altitude,
            mapView.camera.pitch,
            mapView.camera.centerCoordinate.latitude,
            mapView.frame.size
        )
    }

    class func getAltitude(zoom: Double, mapView: MLNMapView) -> Double {
        return MLNAltitudeForZoomLevel(
            zoom,
            mapView.camera.pitch,
            mapView.camera.centerCoordinate.latitude,
            mapView.frame.size
        )
    }

    /// Camera on `center` at `zoom`, keeping pitch and heading. The altitude is
    /// worked out for the new latitude: the same altitude at another latitude
    /// is another zoom level.
    class func cameraLooking(
        at center: CLLocationCoordinate2D,
        zoom: Double,
        mapView: MLNMapView
    ) -> MLNMapCamera {
        let camera = mapView.camera
        let altitude = MLNAltitudeForZoomLevel(
            zoom,
            camera.pitch,
            center.latitude,
            mapView.frame.size
        )
        return MLNMapCamera(
            lookingAtCenter: center,
            altitude: altitude,
            pitch: camera.pitch,
            heading: camera.heading
        )
    }

    /// `cameraThatFitsCoordinateBounds` sizes the zoom for the padded area but
    /// centers the camera on the bounds, expecting the same padding to be
    /// passed again when the camera is set. Passing it would keep it as the
    /// map's camera insets after the move, so the center is shifted here
    /// instead: the bounds land in the middle of the padded area while the
    /// map's own content insets stay as they were, as on Android and web.
    class func cameraFitting(
        _ fit: MLNMapCamera,
        padding: UIEdgeInsets,
        mapView: MLNMapView
    ) -> MLNMapCamera {
        let size = mapView.frame.size
        let zoom = MLNZoomLevelForAltitude(
            fit.altitude,
            fit.pitch,
            fit.centerCoordinate.latitude,
            size
        )
        guard zoom.isFinite else { return fit }
        let center = offset(
            fit.centerCoordinate,
            zoom: zoom,
            heading: fit.heading,
            dx: Double(padding.right - padding.left) / 2,
            dy: Double(padding.bottom - padding.top) / 2
        )
        return MLNMapCamera(
            lookingAtCenter: center,
            altitude: MLNAltitudeForZoomLevel(zoom, fit.pitch, center.latitude, size),
            pitch: fit.pitch,
            heading: fit.heading
        )
    }

    /// The coordinate `dx` points right and `dy` points down on screen from
    /// `center`, for a camera at `zoom` facing `heading`, in Web Mercator with
    /// 512 point tiles. The pitch is left out, as maplibre-gl-js does when it
    /// fits bounds. The longitude is wrapped into [-180, 180). Android does
    /// the same sums.
    class func offset(
        _ center: CLLocationCoordinate2D,
        zoom: Double,
        heading: CLLocationDirection,
        dx: Double,
        dy: Double
    ) -> CLLocationCoordinate2D {
        let worldSize = 512 * pow(2, zoom)
        let radians = heading * Double.pi / 180
        let offsetX = dx * cos(radians) - dy * sin(radians)
        let offsetY = dx * sin(radians) + dy * cos(radians)
        let sinLatitude = sin(center.latitude * Double.pi / 180)
        let x = (center.longitude + 180) / 360 * worldSize + offsetX
        let y = (0.5 - log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * Double.pi)) * worldSize
            + offsetY
        let longitude = (x / worldSize * 360).truncatingRemainder(dividingBy: 360)
        return CLLocationCoordinate2D(
            latitude: atan(sinh(Double.pi * (1 - 2 * y / worldSize))) * 180 / Double.pi,
            longitude: (longitude < 0 ? longitude + 360 : longitude) - 180
        )
    }

    class func getCoordinates(options: Any?) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []

        if let options = options as? [String: Any],
           let geometry = options["geometry"] as? [[Double]], geometry.count > 0
        {
            for coordinate in geometry {
                coordinates.append(CLLocationCoordinate2DMake(coordinate[0], coordinate[1]))
            }
        }
        return coordinates
    }
}
