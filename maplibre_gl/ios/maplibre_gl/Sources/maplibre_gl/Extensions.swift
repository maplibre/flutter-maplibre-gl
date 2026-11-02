import MapLibre

extension MLNMapView {
    /// Where the map is now, as the camera events and calls report it.
    ///
    /// The zoom is the map's own `zoomLevel`, not one worked out from
    /// `camera.altitude`. The altitude is itself derived from the zoom at the
    /// current latitude, so going back through `MLNZoomLevelForAltitude` adds
    /// floating point noise that changes with every pan step (#1150). It also
    /// needs the view size, so before the first layout it is not finite, which
    /// poisons the Dart side's cached position (#903). `zoomLevel` needs
    /// neither.
    var pigeonCameraPosition: PgCameraPosition {
        let camera = self.camera
        return PgCameraPosition(
            bearing: camera.heading,
            target: camera.centerCoordinate.toPigeon(),
            tilt: Double(camera.pitch),
            zoom: zoomLevel
        )
    }
}

extension MLNMapCamera {
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
    /// The location as `mapOnUserLocationUpdated` reports it, timestamp in
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
    /// The heading as `mapOnUserLocationUpdated` reports it, timestamp in
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

    /// Whether both coordinates are finite. MapLibre aborts the app on a NaN
    /// or infinite one.
    var isFinite: Bool {
        return latitude.isFinite && longitude.isFinite
    }
}

extension PgLatLngBounds {
    var coordinateBounds: MLNCoordinateBounds {
        return MLNCoordinateBounds(sw: southwest.coordinate, ne: northeast.coordinate)
    }
}

extension PgLatLngQuad {
    /// Whether the four corners are finite.
    var isFinite: Bool {
        return [topLeft, topRight, bottomRight, bottomLeft].allSatisfy(\.isFinite)
    }

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

public extension UIColor {
    /// The color of a CSS hex color: `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`,
    /// with the alpha last, as MapLibre reads it on Android and web. Nil for
    /// anything else, such as a digit that is not hex.
    convenience init?(hexString: String) {
        guard hexString.hasPrefix("#") else { return nil }
        let digits = hexString.dropFirst()
        guard [3, 4, 6, 8].contains(digits.count),
              digits.allSatisfy({ $0.isASCII && $0.isHexDigit })
        else {
            return nil
        }
        let nibbles: [Int] = digits.compactMap { $0.hexDigitValue }
        var channels: [CGFloat] = []
        if nibbles.count <= 4 {
            // A short color repeats each digit: #f80 is #ff8800.
            for nibble in nibbles {
                channels.append(CGFloat(nibble * 17) / 255)
            }
        } else {
            for index in stride(from: 0, to: nibbles.count, by: 2) {
                let byte: Int = nibbles[index] * 16 + nibbles[index + 1]
                channels.append(CGFloat(byte) / 255)
            }
        }
        self.init(
            red: channels[0],
            green: channels[1],
            blue: channels[2],
            alpha: channels.count == 4 ? channels[3] : 1
        )
    }
}
