import MapLibre
import UIKit

/// The puck colors set through the Dart `MyLocationStyle`. A nil field keeps
/// the SDK default.
///
/// The default puck reads most of its colors from
/// `mapView(styleForDefaultUserLocationAnnotationView:)`, but takes the
/// accuracy circle from its own tint color, and only recolors itself when that
/// tint is set. So the controller hands MapLibre `annotationViewStyle` and also
/// sets `viewTintColor` on the puck view after the SDK redraws or retints it.
struct LocationPuckStyle: Equatable {
    var fillColor: UIColor?
    var bearingColor: UIColor?
    var accuracyColor: UIColor?
    var accuracyCircleEnabled = true
    var pulseEnabled: Bool?
    var pulseColor: UIColor?

    /// True when nothing is customized, so the SDK's own look applies.
    var isDefault: Bool {
        self == LocationPuckStyle()
    }

    /// The SDK's own look.
    init() {}

    /// Reads the `MyLocationStyle` Dart sends.
    init(_ style: PgMyLocationStyle) {
        fillColor = Self.color(style.fillColor)
        bearingColor = Self.color(style.bearingColor)
        // The circle keeps the SDK's own translucency, as on Android and web,
        // so only the color channels are used.
        accuracyColor = Self.color(style.accuracyColor)?.withAlphaComponent(1)
        accuracyCircleEnabled = style.accuracyCircleEnabled
        pulseEnabled = style.pulseEnabled
        pulseColor = Self.color(style.pulseColor)
    }

    private static func color(_ argb: Int64?) -> UIColor? {
        guard let argb = argb else { return nil }
        return UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255.0,
            green: CGFloat((argb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(argb & 0xFF) / 255.0,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255.0
        )
    }

    /// The style returned to MapLibre. Once anything is customized every color
    /// is set explicitly, because the puck view falls back to its tint color
    /// for the missing ones, and that tint is the accuracy circle color then.
    func annotationViewStyle(defaultTint: UIColor) -> MLNUserLocationAnnotationViewStyle {
        let style = MLNUserLocationAnnotationViewStyle()
        if #available(iOS 14, *) {
            // The style object starts at 0.15, but the puck uses 0.25 when no
            // delegate answers. Implementing the delegate must not change the
            // look, so keep the SDK's own value.
            style.approximateHaloOpacity = 0.25
        }
        guard !isDefault else { return style }
        style.puckFillColor = fillColor ?? defaultTint
        style.puckArrowFillColor = bearingColor ?? defaultTint
        style.haloFillColor = pulseEnabled == false ? .clear : (pulseColor ?? defaultTint)
        if #available(iOS 14, *) {
            style.approximateHaloFillColor = accuracyColor ?? defaultTint
        }
        return style
    }

    /// The tint for the puck view. In course tracking the view draws an arrow
    /// and outlines it with the tint, so the tint is the arrow color there.
    func viewTintColor(defaultTint: UIColor, followingCourse: Bool) -> UIColor {
        if followingCourse {
            return bearingColor ?? defaultTint
        }
        guard accuracyCircleEnabled else { return .clear }
        return accuracyColor ?? defaultTint
    }
}

/// The map view the plugin creates. MLNMapView hands its own tint to the puck
/// view whenever its tint changes, for example when a sheet dims the window,
/// which undoes the accuracy circle color. This reports those changes so the
/// controller can apply the puck tint again.
final class LocationPuckMapView: MLNMapView {
    var onTintColorDidChange: (() -> Void)?

    override func tintColorDidChange() {
        super.tintColorDidChange()
        onTintColorDidChange?()
    }
}
