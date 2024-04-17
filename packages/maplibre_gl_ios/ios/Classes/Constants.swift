import MapLibre

/*
 * The mapping is based on the values defined here:
 *  https://docs.mapbox.com/android/api/map-sdk/8.4.0/constant-values.html
 */

class Constants {
    static let symbolIconAnchorMapping = [
        "center": MLNIconAnchor.center,
        "left": MLNIconAnchor.left,
        "right": MLNIconAnchor.right,
        "top": MLNIconAnchor.top,
        "bottom": MLNIconAnchor.bottom,
        "top-left": MLNIconAnchor.topLeft,
        "top-right": MLNIconAnchor.topRight,
        "bottom-left": MLNIconAnchor.bottomLeft,
        "bottom-right": MLNIconAnchor.bottomRight,
    ]

    static let symbolTextJustificationMapping = [
        "auto": MLNTextJustification.auto,
        "center": MLNTextJustification.center,
        "left": MLNTextJustification.left,
        "right": MLNTextJustification.right,
    ]

    static let symbolTextAnchorMapping = [
        "center": MLNTextAnchor.center,
        "left": MLNTextAnchor.left,
        "right": MLNTextAnchor.right,
        "top": MLNTextAnchor.top,
        "bottom": MLNTextAnchor.bottom,
        "top-left": MLNTextAnchor.topLeft,
        "top-right": MLNTextAnchor.topRight,
        "bottom-left": MLNTextAnchor.bottomLeft,
        "bottom-right": MLNTextAnchor.bottomRight,
    ]

    static let symbolTextTransformationMapping = [
        "none": MLNTextTransform.none,
        "lowercase": MLNTextTransform.lowercase,
        "uppercase": MLNTextTransform.uppercase,
    ]

    static let lineJoinMapping = [
        "bevel": MLNLineJoin.bevel,
        "miter": MLNLineJoin.miter,
        "round": MLNLineJoin.round,
    ]
}
