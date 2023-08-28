library mapboxgl.ui.marker;

import 'dart:html';
import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/ui/popup.dart';
import 'package:maplibre_gl_web/src/geo/point.dart';
import 'package:maplibre_gl_web/src/util/evented.dart';

/// Creates a marker component
/// @param {HTMLElement} [element] DOM element to use as a marker. The default is a light blue, droplet-shaped SVG marker.
/// @param {string} [anchor='center'] A string indicating the part of the Marker that should be positioned closest to the coordinate set via {@link Marker#setLngLat}.
///   Options are `'center'`, `'top'`, `'bottom'`, `'left'`, `'right'`, `'top-left'`, `'top-right'`, `'bottom-left'`, and `'bottom-right'`.
/// @param {PointLike} [offset] The offset in pixels as a {@link PointLike} object to apply relative to the element's center. Negatives indicate left and up.
/// @param {string} [color='#3FB1CE'] The color to use for the default marker if `element` is not provided. The default is light blue.
/// @param {boolean} [draggable=false] A boolean indicating whether or not a marker is able to be dragged to a new position on the map.
/// @param {number} [rotation=0] The rotation angle of the marker in degrees, relative to its respective {@link Marker#rotationAlignment} setting. A positive value will rotate the marker clockwise.
/// @param {string} [pitchAlignment='auto'] `map` aligns the `Marker` to the plane of the map. `viewport` aligns the `Marker` to the plane of the viewport. `auto` automatically matches the value of `rotationAlignment`.
/// @param {string} [rotationAlignment='auto'] `map` aligns the `Marker`'s rotation relative to the map, maintaining a bearing as the map rotates. `viewport` aligns the `Marker`'s rotation relative to the viewport, agnostic to map rotations. `auto` is equivalent to `viewport`.
/// ```dart
/// var marker = mapboxgl.Marker()
///   .setLngLat([30.5, 50.5])
///   .addTo(map);
/// ```
/// @see [Add custom icons with Markers](https://www.mapbox.com/mapbox-gl-js/example/custom-marker-icons/)
/// @see [Create a draggable Marker](https://www.mapbox.com/mapbox-gl-js/example/drag-a-marker/)
class Marker extends Evented {
  final MarkerJsImpl jsObject;

  factory Marker([MarkerOptions? options]) =>
      Marker.fromJsObject(MarkerJsImpl(options?.jsObject));

  ///  Attaches the marker to a map
  ///  @param {MapboxMap} map
  ///  @returns {Marker} `this`
  Marker addTo(MapboxMap map) =>
      Marker.fromJsObject(jsObject.addTo(map.jsObject));

  ///  Removes the marker from a map
  ///  @example
  ///  var marker = new mapboxgl.Marker().addTo(map);
  ///  marker.remove();
  ///  @returns {Marker} `this`
  Marker remove() => Marker.fromJsObject(jsObject.remove());

  ///  Get the marker's geographical location.
  ///
  ///  The longitude of the result may differ by a multiple of 360 degrees from the longitude previously
  ///  set by `setLngLat` because `Marker` wraps the anchor longitude across copies of the world to keep
  ///  the marker on screen.
  ///
  ///  @returns {LngLat}
  LngLat getLngLat() => LngLat.fromJsObject(jsObject.getLngLat());

  ///  Set the marker's geographical position and move it.
  ///  @returns {Marker} `this`
  Marker setLngLat(LngLat lnglat) =>
      Marker.fromJsObject(jsObject.setLngLat(lnglat.jsObject));

  ///  Returns the `Marker`'s HTML element.
  ///  @returns {HtmlElement} element
  HtmlElement getElement() => jsObject.getElement();

  ///  Binds a Popup to the Marker
  ///  @param popup an instance of the `Popup` class. If undefined or null, any popup
  ///  set on this `Marker` instance is unset
  ///  @returns {Marker} `this`
  Marker setPopup(Popup popup) =>
      Marker.fromJsObject(jsObject.setPopup(popup.jsObject));

  ///  Returns the Popup instance that is bound to the Marker
  ///  @returns {Popup} popup
  Popup getPopup() => Popup.fromJsObject(jsObject.getPopup());

  ///  Opens or closes the bound popup, depending on the current state
  ///  @returns {Marker} `this`
  Marker togglePopup() => Marker.fromJsObject(jsObject.togglePopup());

  ///  Get the marker's offset.
  ///  @returns {Point}
  Point getOffset() => Point.fromJsObject(jsObject.getOffset());

  ///  Sets the offset of the marker
  ///  @param {PointLike} offset The offset in pixels as a {@link PointLike} object to apply relative to the element's center. Negatives indicate left and up.
  ///  @returns {Marker} `this`
  Marker setOffset(Point offset) =>
      Marker.fromJsObject(jsObject.setOffset(offset.jsObject));

  ///  Sets the `draggable` property and functionality of the marker
  ///  @param {boolean} [shouldBeDraggable=false] Turns drag functionality on/off
  ///  @returns {Marker} `this`
  Marker setDraggable(bool shouldBeDraggable) =>
      Marker.fromJsObject(jsObject.setDraggable(shouldBeDraggable));

  ///  Returns true if the marker can be dragged
  ///  @returns {boolean}
  bool isDraggable() => jsObject.isDraggable();

  ///  Sets the `rotation` property of the marker.
  ///  @param {number} [rotation=0] The rotation angle of the marker (clockwise, in degrees), relative to its respective {@link Marker#rotationAlignment} setting.
  ///  @returns {Marker} `this`
  Marker setRotation(num rotation) =>
      Marker.fromJsObject(jsObject.setRotation(rotation));

  ///  Returns the current rotation angle of the marker (in degrees).
  ///  @returns {number}
  num getRotation() => jsObject.getRotation();

  ///  Sets the `rotationAlignment` property of the marker.
  ///  @param {string} [alignment='auto'] Sets the `rotationAlignment` property of the marker.
  ///  @returns {Marker} `this`
  Marker setRotationAlignment(String alignment) =>
      Marker.fromJsObject(jsObject.setRotationAlignment(alignment));

  ///  Returns the current `rotationAlignment` property of the marker.
  ///  @returns {string}
  String getRotationAlignment() => jsObject.getRotationAlignment();

  ///  Sets the `pitchAlignment` property of the marker.
  ///  @param {string} [alignment] Sets the `pitchAlignment` property of the marker. If alignment is 'auto', it will automatically match `rotationAlignment`.
  ///  @returns {Marker} `this`
  Marker setPitchAlignment(String alignment) =>
      Marker.fromJsObject(jsObject.setPitchAlignment(alignment));

  ///  Returns the current `pitchAlignment` property of the marker.
  ///  @returns {string}
  String getPitchAlignment() => jsObject.getPitchAlignment();

  /// Creates a new Marker from a [jsObject].
  Marker.fromJsObject(this.jsObject) : super.fromJsObject(jsObject);
}

class MarkerOptions extends JsObjectWrapper<MarkerOptionsJsImpl> {
  factory MarkerOptions({
    HtmlElement? element,
    Point? offset,
    String? anchor,
    String? color,
    bool? draggable,
    num? rotation,
    String? rotationAlignment,
    String? pitchAlignment,
  }) =>
      MarkerOptions.fromJsObject(MarkerOptionsJsImpl(
        element: element,
        offset: offset?.jsObject,
        anchor: anchor,
        color: color,
        draggable: draggable,
        rotation: rotation,
        rotationAlignment: rotationAlignment,
        pitchAlignment: pitchAlignment,
      ));

  /// Creates a new MarkerOptions from a [jsObject].
  MarkerOptions.fromJsObject(MarkerOptionsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
