@JS('maplibregl')
library maplibre.interop.ui.popup;

import 'dart:html';
import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

/// A popup component.
///
/// @param {Object} [options]
/// @param {boolean} [options.closeButton=true] If `true`, a close button will appear in the
///   top right corner of the popup.
/// @param {boolean} [options.closeOnClick=true] If `true`, the popup will closed when the
///   map is clicked.
/// @param {string} [options.anchor] - A string indicating the part of the Popup that should
///   be positioned closest to the coordinate set via {@link Popup#setLngLat}.
///   Options are `'center'`, `'top'`, `'bottom'`, `'left'`, `'right'`, `'top-left'`,
///   `'top-right'`, `'bottom-left'`, and `'bottom-right'`. If unset the anchor will be
///   dynamically set to ensure the popup falls within the map container with a preference
///   for `'bottom'`.
/// @param {number|PointLike|Object} [options.offset] -
///  A pixel offset applied to the popup's location specified as:
///   - a single number specifying a distance from the popup's location
///   - a {@link PointLike} specifying a constant offset
///   - an object of {@link Point}s specifing an offset for each anchor position
///  Negative offsets indicate left and up.
/// @param {string} [options.className] Space-separated CSS class names to add to popup container
/// @param {string} [options.maxWidth='240px'] -
///  A string that sets the CSS property of the popup's maximum width, eg `'300px'`.
///  To ensure the popup resizes to fit its content, set this property to `'none'`.
///  Available values can be found here: https://developer.mozilla.org/en-US/docs/Web/CSS/max-width
/// @example
/// var markerHeight = 50, markerRadius = 10, linearOffset = 25;
/// var popupOffsets = {
///  'top': [0, 0],
///  'top-left': [0,0],
///  'top-right': [0,0],
///  'bottom': [0, -markerHeight],
///  'bottom-left': [linearOffset, (markerHeight - markerRadius + linearOffset) /// -1],
///  'bottom-right': [-linearOffset, (markerHeight - markerRadius + linearOffset) /// -1],
///  'left': [markerRadius, (markerHeight - markerRadius) /// -1],
///  'right': [-markerRadius, (markerHeight - markerRadius) /// -1]
///  };
/// var popup = new maplibregl.Popup({offset: popupOffsets, className: 'my-class'})
///   .setLngLat(e.lngLat)
///   .setHTML("<h1>Hello World!</h1>")
///   .setMaxWidth("300px")
///   .addTo(map);
/// @see [Display a popup](https://maplibre.org/maplibre-gl-js/docs/examples/popup/)
/// @see [Display a popup on hover](https://maplibre.org/maplibre-gl-js/docs/examples/popup-on-hover/)
/// @see [Display a popup on click](https://maplibre.org/maplibre-gl-js/docs/examples/popup-on-click/)
/// @see [Attach a popup to a marker instance](https://maplibre.org/maplibre-gl-js/docs/examples/set-popup/)
@JS('Popup')
class PopupJsImpl extends EventedJsImpl {
  external dynamic get options;

  external factory PopupJsImpl([PopupOptionsJsImpl? options]);

  /// Adds the popup to a map.
  ///
  /// @param {MapLibreMap} map The MapLibre JS JS map to add the popup to.
  /// @returns {Popup} `this`
  external PopupJsImpl addTo(MapLibreMapJsImpl map);

  /// @returns {boolean} `true` if the popup is open, `false` if it is closed.
  external bool isOpen();

  /// Removes the popup from the map it has been added to.
  ///
  /// @example
  /// var popup = new maplibregl.Popup().addTo(map);
  /// popup.remove();
  /// @returns {Popup} `this`
  external PopupJsImpl remove();

  /// Returns the geographical location of the popup's anchor.
  ///
  /// The longitude of the result may differ by a multiple of 360 degrees from the longitude previously
  /// set by `setLngLat` because `Popup` wraps the anchor longitude across copies of the world to keep
  /// the popup on screen.
  ///
  /// @returns {LngLat} The geographical location of the popup's anchor.
  external LngLatJsImpl getLngLat();

  /// Sets the geographical location of the popup's anchor, and moves the popup to it. Replaces trackPointer() behavior.
  ///
  /// @param lnglat The geographical location to set as the popup's anchor.
  /// @returns {Popup} `this`
  external PopupJsImpl setLngLat(LngLatJsImpl lnglat);

  /// Tracks the popup anchor to the cursor position, on screens with a pointer device (will be hidden on touchscreens). Replaces the setLngLat behavior.
  /// For most use cases, `closeOnClick` and `closeButton` should also be set to `false` here.
  /// @returns {Popup} `this`
  ////
  external PopupJsImpl trackPointer();

  /// Returns the `Popup`'s HTML element.
  /// @returns {HtmlElement} element
  external HtmlElement getElement();

  /// Sets the popup's content to a string of text.
  ///
  /// This function creates a [Text](https://developer.mozilla.org/en-US/docs/Web/API/Text) node in the DOM,
  /// so it cannot insert raw HTML. Use this method for security against XSS
  /// if the popup content is user-provided.
  ///
  /// @param text Textual content for the popup.
  /// @returns {Popup} `this`
  /// @example
  /// var popup = new maplibregl.Popup()
  ///   .setLngLat(e.lngLat)
  ///   .setText('Hello, world!')
  ///   .addTo(map);
  external PopupJsImpl setText(String text);

  /// Sets the popup's content to the HTML provided as a string.
  ///
  /// This method does not perform HTML filtering or sanitization, and must be
  /// used only with trusted content. Consider {@link Popup#setText} if
  /// the content is an untrusted text string.
  ///
  /// @param html A string representing HTML content for the popup.
  /// @returns {Popup} `this`
  external PopupJsImpl setHTML(String? html);

  /// Returns the popup's maximum width.
  ///
  /// @returns {string} The maximum width of the popup.
  ////
  external String getMaxWidth();

  /// Sets the popup's maximum width. This is setting the CSS property `max-width`.
  /// Available values can be found here: https://developer.mozilla.org/en-US/docs/Web/CSS/max-width
  ///
  /// @param maxWidth A string representing the value for the maximum width.
  /// @returns {Popup} `this`
  external PopupJsImpl setMaxWidth(String maxWidth);

  /// Sets the popup's content to the element provided as a DOM node.
  ///
  /// @param htmlNode A DOM node to be used as content for the popup.
  /// @returns {Popup} `this`
  /// @example
  /// // create an element with the popup content
  /// var div = window.document.createElement('div');
  /// div.innerHTML = 'Hello, world!';
  /// var popup = new maplibregl.Popup()
  ///   .setLngLat(e.lngLat)
  ///   .setDOMContent(div)
  ///   .addTo(map);
  external PopupJsImpl setDOMContent(Node htmlNode);

  /// Adds a CSS class to the popup container element.
  ///
  /// @param {string} className Non-empty string with CSS class name to add to popup container
  ///
  /// @example
  /// let popup = new maplibregl.Popup()
  /// popup.addClassName('some-class')
  external addClassName(String className);

  /// Removes a CSS class from the popup container element.
  ///
  /// @param {string} className Non-empty string with CSS class name to remove from popup container
  ///
  /// @example
  /// let popup = new maplibregl.Popup()
  /// popup.removeClassName('some-class')
  external removeClassName(String className);

  /// Add or remove the given CSS class on the popup container, depending on whether the container currently has that class.
  ///
  /// @param {string} className Non-empty string with CSS class name to add/remove
  ///
  /// @returns {boolean} if the class was removed return false, if class was added, then return true
  ///
  /// @example
  /// let popup = new maplibregl.Popup()
  /// popup.toggleClassName('toggleClass')
  external bool toggleClassName(String className);
}

@JS()
@anonymous
class PopupOptionsJsImpl {
  external factory PopupOptionsJsImpl({
    bool? loseButton,
    bool? closeButton,
    bool? closeOnClick,
    String? anchor,
    dynamic offset,
    String? className,
    String? maxWidth,
  });
}
