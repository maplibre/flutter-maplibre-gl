@JS('maplibregl')
library mapboxgl.interop.ui.marker;

import 'dart:html';
import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_interop.dart';
import 'package:maplibre_gl_web/src/interop/geo/point_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/popup_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

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
@JS('Marker')
class MarkerJsImpl extends EventedJsImpl {
  external factory MarkerJsImpl([MarkerOptionsJsImpl? options]);

  ///  Attaches the marker to a map
  ///  @param {MapboxMap} map
  ///  @returns {Marker} `this`
  external MarkerJsImpl addTo(MapboxMapJsImpl map);

  ///  Removes the marker from a map
  ///  @example
  ///  var marker = new mapboxgl.Marker().addTo(map);
  ///  marker.remove();
  ///  @returns {Marker} `this`
  external MarkerJsImpl remove();

  ///  Get the marker's geographical location.
  ///
  ///  The longitude of the result may differ by a multiple of 360 degrees from the longitude previously
  ///  set by `setLngLat` because `Marker` wraps the anchor longitude across copies of the world to keep
  ///  the marker on screen.
  ///
  ///  @returns {LngLat}
  external LngLatJsImpl getLngLat();

  ///  Set the marker's geographical position and move it.
  ///  @returns {Marker} `this`
  external MarkerJsImpl setLngLat(LngLatJsImpl lnglat);

  ///  Returns the `Marker`'s HTML element.
  ///  @returns {HtmlElement} element
  external HtmlElement getElement();

  ///  Binds a Popup to the Marker
  ///  @param popup an instance of the `Popup` class. If undefined or null, any popup
  ///  set on this `Marker` instance is unset
  ///  @returns {Marker} `this`
  external MarkerJsImpl setPopup(PopupJsImpl popup);

  ///  Returns the Popup instance that is bound to the Marker
  ///  @returns {Popup} popup
  external PopupJsImpl getPopup();

  ///  Opens or closes the bound popup, depending on the current state
  ///  @returns {Marker} `this`
  external MarkerJsImpl togglePopup();

  ///  Get the marker's offset.
  ///  @returns {Point}
  external PointJsImpl getOffset();

  ///  Sets the offset of the marker
  ///  @param {PointLike} offset The offset in pixels as a {@link PointLike} object to apply relative to the element's center. Negatives indicate left and up.
  ///  @returns {Marker} `this`
  external MarkerJsImpl setOffset(PointJsImpl offset);

  ///  Sets the `draggable` property and functionality of the marker
  ///  @param {boolean} [shouldBeDraggable=false] Turns drag functionality on/off
  ///  @returns {Marker} `this`
  external MarkerJsImpl setDraggable(bool shouldBeDraggable);

  ///  Returns true if the marker can be dragged
  ///  @returns {boolean}
  external bool isDraggable();

  ///  Sets the `rotation` property of the marker.
  ///  @param {number} [rotation=0] The rotation angle of the marker (clockwise, in degrees), relative to its respective {@link Marker#rotationAlignment} setting.
  ///  @returns {Marker} `this`
  external MarkerJsImpl setRotation(num rotation);

  ///  Returns the current rotation angle of the marker (in degrees).
  ///  @returns {number}
  external num getRotation();

  ///  Sets the `rotationAlignment` property of the marker.
  ///  @param {string} [alignment='auto'] Sets the `rotationAlignment` property of the marker.
  ///  @returns {Marker} `this`
  external MarkerJsImpl setRotationAlignment(String alignment);

  ///  Returns the current `rotationAlignment` property of the marker.
  ///  @returns {string}
  external String getRotationAlignment();

  ///  Sets the `pitchAlignment` property of the marker.
  ///  @param {string} [alignment] Sets the `pitchAlignment` property of the marker. If alignment is 'auto', it will automatically match `rotationAlignment`.
  ///  @returns {Marker} `this`
  external MarkerJsImpl setPitchAlignment(String alignment);

  ///  Returns the current `pitchAlignment` property of the marker.
  ///  @returns {string}
  external String getPitchAlignment();
}

@JS()
@anonymous
class MarkerOptionsJsImpl {
  external factory MarkerOptionsJsImpl({
    HtmlElement? element,
    PointJsImpl? offset,
    String? anchor,
    String? color,
    bool? draggable,
    num? rotation,
    String? rotationAlignment,
    String? pitchAlignment,
  });
}
