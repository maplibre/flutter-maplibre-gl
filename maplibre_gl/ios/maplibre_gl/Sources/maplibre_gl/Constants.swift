import MapLibre

/*
 * The string keys below are the style spec's own values for icon-anchor,
 * text-anchor and the other symbol layout properties:
 *  https://maplibre.org/maplibre-style-spec/layers/
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
