import QuartzCore

extension CAMediaTimingFunction {
    /// A timing function that eases MLNMapView's camera animations along (0, 0, x, y).
    ///
    /// MLNMapView (MapLibre iOS 6.31 and 7.0) hands MapLibre Native the points at index 0 and 1
    /// of a timing function, the first one the start of the curve, always (0, 0). So a camera
    /// animation eases along (0, 0, c1x, c1y) instead of (c1x, c1y, c2x, c2y), and only curves
    /// starting with (0, 0) can be had, through the first control point. Core Animation hands
    /// back a shared instance for its named curves, so a subclass reading out the right points
    /// cannot work around it.
    ///
    /// `setContentInset(_:animated:)` takes no timing function, so animated content insets
    /// still ease along the wrong curve. Drop this, in every camera animation at once, once
    /// MapLibre iOS reads index 1 and 2: https://github.com/maplibre/maplibre-native/issues/4902
    static func cameraEasing(_ x: Float, _ y: Float) -> CAMediaTimingFunction {
        return CAMediaTimingFunction(controlPoints: x, y, 1, 1)
    }

    /// MapLibre Native's own easing, (0, 0, 0.25, 1): the one Android eases camera calls with,
    /// unless they are linear.
    static let nativeCameraEasing = cameraEasing(0.25, 1)
}
