import MapLibre

extension MLNMapCamera {
    /// The camera as the camera events and calls report it.
    func toPigeon(mapView: MLNMapView) -> PgCameraPosition {
        return PgCameraPosition(
            bearing: heading,
            target: centerCoordinate.toPigeon(),
            tilt: Double(pitch),
            zoom: finiteZoom(mapView: mapView)
        )
    }

    private func finiteZoom(mapView: MLNMapView) -> Double {
        // MLNZoomLevelForAltitude derives the zoom from the view size, so a
        // camera event that arrives before the map view has a laid-out frame
        // divides by zero and yields a non-finite zoom. Sending that over the
        // channel poisons the controller's cached camera position on the Dart
        // side, and on a map nobody touches no later event arrives to correct
        // it (#903). The map view's own zoomLevel needs no view size and is
        // always finite, so it stands in.
        let computedZoom = MLNZoomLevelForAltitude(
            altitude,
            pitch,
            centerCoordinate.latitude,
            mapView.frame.size
        )
        return computedZoom.isFinite ? Double(computedZoom) : mapView.zoomLevel
    }

    /// The camera at `position`, its altitude worked out for the current size
    /// of the map view.
    static func fromPigeon(_ position: PgCameraPosition, mapView: MLNMapView) -> MLNMapCamera {
        let location = position.target.coordinate
        let tilt = CGFloat(position.tilt)
        let altitude = MLNAltitudeForZoomLevel(
            position.zoom,
            tilt,
            location.latitude,
            mapView.frame.size
        )
        return MLNMapCamera(
            lookingAtCenter: location,
            altitude: altitude,
            pitch: tilt,
            heading: position.bearing
        )
    }
}

extension MLNCameraChangeReason {
    /// The reasons that name a gesture of the user.
    static let gestures: MLNCameraChangeReason = [
        .gesturePan,
        .gesturePinch,
        .gestureRotate,
        .gestureZoomIn,
        .gestureZoomOut,
        .gestureOneFingerZoom,
        .gestureTilt,
    ]
}

extension CLLocation {
    /// The location as `map#onUserLocationUpdated` reports it, timestamp in
    /// milliseconds since the epoch.
    func toPigeon() -> PgUserLocation {
        return PgUserLocation(
            position: coordinate.toPigeon(),
            altitude: altitude,
            bearing: course,
            speed: speed,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: Int64(timestamp.timeIntervalSince1970 * 1000)
        )
    }
}

extension CLHeading {
    /// The heading as `map#onUserLocationUpdated` reports it, timestamp in
    /// milliseconds since the epoch.
    func toPigeon() -> PgUserHeading {
        return PgUserHeading(
            magneticHeading: magneticHeading,
            trueHeading: trueHeading,
            headingAccuracy: headingAccuracy,
            x: x,
            y: y,
            z: z,
            timestamp: Int64(timestamp.timeIntervalSince1970 * 1000)
        )
    }
}

extension CLLocationCoordinate2D {
    func toPigeon() -> PgLatLng {
        return PgLatLng(latitude: latitude, longitude: longitude)
    }
}

extension MLNCoordinateBounds {
    func toPigeon() -> PgLatLngBounds {
        return PgLatLngBounds(southwest: sw.toPigeon(), northeast: ne.toPigeon())
    }
}

extension PgLatLng {
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension PgLatLngBounds {
    var coordinateBounds: MLNCoordinateBounds {
        return MLNCoordinateBounds(sw: southwest.coordinate, ne: northeast.coordinate)
    }
}

extension PgLatLngQuad {
    var coordinateQuad: MLNCoordinateQuad {
        return MLNCoordinateQuad(
            topLeft: topLeft.coordinate,
            bottomLeft: bottomLeft.coordinate,
            bottomRight: bottomRight.coordinate,
            topRight: topRight.coordinate
        )
    }
}

extension PgEdgeInsets {
    var edgeInsets: UIEdgeInsets {
        return UIEdgeInsets(
            top: CGFloat(top),
            left: CGFloat(left),
            bottom: CGFloat(bottom),
            right: CGFloat(right)
        )
    }
}

extension UIImage {
    static func loadFromFile(imagePath: String, imageName: String) -> UIImage? {
        // Add the trailing slash in path if missing.
        let path = imagePath.hasSuffix("/") ? imagePath : "\(imagePath)/"
        // Build scale dependant image path.
        var scale = UIScreen.main.scale
        var absolutePath = "\(path)\(scale)x/\(imageName)"
        // Check if the image exists, if not try a an unscaled path.
        if Bundle.main.path(forResource: absolutePath, ofType: nil) == nil {
            absolutePath = "\(path)\(imageName)"
        } else {
            // found asset with higher resolution - increase scale even further to compensate
            scale *= scale
        }
        // Load image if it exists.
        if let path = Bundle.main.path(forResource: absolutePath, ofType: nil) {
            let imageUrl = URL(fileURLWithPath: path)
            if let imageData: Data = try? Data(contentsOf: imageUrl),
               let image = UIImage(data: imageData, scale: scale)
            {
                return image
            }
        }
        return nil
    }
}

public extension UIColor {
    convenience init?(hexString: String) {
        let r, g, b, a: CGFloat

        if hexString.hasPrefix("#") {
            let start = hexString.index(hexString.startIndex, offsetBy: 1)
            let hexColor = hexString[start...]

            let scanner = Scanner(string: String(hexColor))
            var hexNumber: UInt64 = 0

            if hexColor.count == 6 {
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000FF) / 255
                    a = 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            } else if hexColor.count == 8 {
                if scanner.scanHexInt64(&hexNumber) {
                    a = CGFloat((hexNumber & 0xFF00_0000) >> 24) / 255
                    r = CGFloat((hexNumber & 0x00FF_0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x0000_FF00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000_00FF) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
