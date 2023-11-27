library maplibre.ui.map;

import 'dart:html';
import 'package:js/js_util.dart';
import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/geo/lng_lat_bounds.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/geo/point.dart';
import 'package:maplibre_gl_web/src/style/layers/layer.dart';
import 'package:maplibre_gl_web/src/style/sources/geojson_source.dart';
import 'package:maplibre_gl_web/src/style/sources/source.dart';
import 'package:maplibre_gl_web/src/style/sources/vector_source.dart';
import 'package:maplibre_gl_web/src/style/style.dart';
import 'package:maplibre_gl_web/src/ui/camera.dart';
import 'package:maplibre_gl_web/src/ui/handler/box_zoom.dart';
import 'package:maplibre_gl_web/src/ui/handler/dblclick_zoom.dart';
import 'package:maplibre_gl_web/src/ui/handler/drag_pan.dart';
import 'package:maplibre_gl_web/src/ui/handler/drag_rotate.dart';
import 'package:maplibre_gl_web/src/ui/handler/keyboard.dart';
import 'package:maplibre_gl_web/src/ui/handler/scroll_zoom.dart';
import 'package:maplibre_gl_web/src/ui/handler/touch_zoom_rotate.dart';

///  The `MapLibreMap` object represents the map on your page. It exposes methods
///  and properties that enable you to programmatically change the map,
///  and fires events as users interact with it.
///
///  You create a `MapLibreMap` by specifying a `container` and other options.
///  Then MapLibre JS JS initializes the map on the page and returns your `MapLibreMap`
///  object.
///
///  ```dart
///  var map = MapLibreMap(
///    MapOptions(
///      container: 'map',
///      center: LngLat(-122.420679, 37.772537),
///      zoom: 13,
///      style: style_object,
///      hash: true,
///      transformRequest: (url, resourceType) {
///        if (resourceType == 'Source' && url.startsWith('http://myHost')) {
///          return RequestParameters(
///            url: url.replaceAll('http', 'https'),
///            headers: {'my-custom-header': true},
///            credentials: 'include',
///          );
///        }
///        return RequestParameters(url: url);
///      },
///    ),
///  );
///  ```
///  @see [Display a map](https://maplibre.org/maplibre-gl-js/docs/examples/simple-map/)
class MapLibreMap extends Camera {
  final MapLibreMapJsImpl jsObject;

  factory MapLibreMap(MapOptions options) =>
      MapLibreMap.fromJsObject(MapLibreMapJsImpl(options.jsObject));

  Style get style => Style.fromJsObject(jsObject.style);

  dynamic get painter => jsObject.painter;

  ///  The map's {@link ScrollZoomHandler}, which implements zooming in and out with a scroll wheel or trackpad.
  ///  Find more details and examples using `scrollZoom` in the {@link ScrollZoomHandler} section.
  ScrollZoomHandler get scrollZoom =>
      ScrollZoomHandler.fromJsObject(jsObject.scrollZoom);

  ///  The map's {@link BoxZoomHandler}, which implements zooming using a drag gesture with the Shift key pressed.
  ///  Find more details and examples using `boxZoom` in the {@link BoxZoomHandler} section.
  BoxZoomHandler get boxZoom => BoxZoomHandler.fromJsObject(jsObject.boxZoom);

  ///  The map's {@link DragRotateHandler}, which implements rotating the map while dragging with the right
  ///  mouse button or with the Control key pressed. Find more details and examples using `dragRotate`
  ///  in the {@link DragRotateHandler} section.
  DragRotateHandler get dragRotate =>
      DragRotateHandler.fromJsObject(jsObject.dragRotate);

  ///  The map's {@link DragPanHandler}, which implements dragging the map with a mouse or touch gesture.
  ///  Find more details and examples using `dragPan` in the {@link DragPanHandler} section.
  DragPanHandler get dragPan => DragPanHandler.fromJsObject(jsObject.dragPan);

  ///  The map's {@link KeyboardHandler}, which allows the user to zoom, rotate, and pan the map using keyboard
  ///  shortcuts. Find more details and examples using `keyboard` in the {@link KeyboardHandler} section.
  KeyboardHandler get keyboard =>
      KeyboardHandler.fromJsObject(jsObject.keyboard);

  ///  The map's {@link DoubleClickZoomHandler}, which allows the user to zoom by double clicking.
  ///  Find more details and examples using `doubleClickZoom` in the {@link DoubleClickZoomHandler} section.
  DoubleClickZoomHandler get doubleClickZoom =>
      DoubleClickZoomHandler.fromJsObject(jsObject.doubleClickZoom);

  ///  The map's {@link TouchZoomRotateHandler}, which allows the user to zoom or rotate the map with touch gestures.
  ///  Find more details and examples using `touchZoomRotate` in the {@link TouchZoomRotateHandler} section.
  TouchZoomRotateHandler get touchZoomRotate =>
      TouchZoomRotateHandler.fromJsObject(jsObject.touchZoomRotate);

  ///  Adds an {@link IControl} to the map, calling `control.onAdd(this)`.
  ///
  ///  @param {IControl} control The {@link IControl} to add.
  ///  @param {string} [position] position on the map to which the control will be added.
  ///  Valid values are `'top-left'`, `'top-right'`, `'bottom-left'`, and `'bottom-right'`. Defaults to `'top-right'`.
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  // Add zoom and rotation controls to the map.
  ///  map.addControl(new NavigationControl());
  ///  @see [Display map navigation controls](https://maplibre.org/maplibre-gl-js/docs/examples/navigation/)
  MapLibreMap addControl(dynamic control, [String? position]) {
    if (position != null) {
      return MapLibreMap.fromJsObject(
          jsObject.addControl(control.jsObject, position));
    }
    return MapLibreMap.fromJsObject(jsObject.addControl(control.jsObject));
  }

  ///  Removes the control from the map.
  ///
  ///  @param {IControl} control The {@link IControl} to remove.
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  // Define a new navigation control.
  ///  var navigation = new NavigationControl();
  ///  // Add zoom and rotation controls to the map.
  ///  map.addControl(navigation);
  ///  // Remove zoom and rotation controls from the map.
  ///  map.removeControl(navigation);
  MapLibreMap removeControl(dynamic control) =>
      MapLibreMap.fromJsObject(jsObject.removeControl(control.jsObject));

  ///  Resizes the map according to the dimensions of its
  ///  `container` element.
  ///
  ///  Checks if the map container size changed and updates the map if it has changed.
  ///  This method must be called after the map's `container` is resized programmatically
  ///  or when the map is shown after being initially hidden with CSS.
  ///
  ///  @param eventData Additional properties to be passed to `movestart`, `move`, `resize`, and `moveend`
  ///    events that get triggered as a result of resize. This can be useful for differentiating the
  ///    source of an event (for example, user-initiated or programmatically-triggered events).
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  // Resize the map when the map container is shown
  ///  // after being initially hidden with CSS.
  ///  var mapDiv = document.getElementById('map');
  ///  if (mapDiv.style.visibility === true) map.resize();
  MapLibreMap resize([dynamic eventData]) =>
      MapLibreMap.fromJsObject(jsObject.resize());

  ///  Returns the map's geographical bounds. When the bearing or pitch is non-zero, the visible region is not
  ///  an axis-aligned rectangle, and the result is the smallest bounds that encompasses the visible region.
  ///  @example
  ///  var bounds = map.getBounds();
  LngLatBounds getBounds() => LngLatBounds.fromJsObject(jsObject.getBounds());

  ///  Returns the maximum geographical bounds the map is constrained to, or `null` if none set.
  ///  @example
  ///  var maxBounds = map.getMaxBounds();
  LngLatBounds getMaxBounds() =>
      LngLatBounds.fromJsObject(jsObject.getMaxBounds());

  ///  Sets or clears the map's geographical bounds.
  ///
  ///  Pan and zoom operations are constrained within these bounds.
  ///  If a pan or zoom is performed that would
  ///  display regions outside these bounds, the map will
  ///  instead display a position and zoom level
  ///  as close as possible to the operation's request while still
  ///  remaining within the bounds.
  ///
  ///  @param {LngLatBoundsLike | null | undefined} bounds The maximum bounds to set. If `null` or `undefined` is provided, the function removes the map's maximum bounds.
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  // Define bounds that conform to the `LngLatBoundsLike` object.
  ///  var bounds = [
  ///    [-74.04728, 40.68392], // [west, south]
  ///    [-73.91058, 40.87764]  // [east, north]
  ///  ];
  ///  // Set the map's max bounds.
  ///  map.setMaxBounds(bounds);
  MapLibreMap setMaxBounds(LngLatBounds? bounds) =>
      MapLibreMap.fromJsObject(jsObject.setMaxBounds(bounds?.jsObject));

  ///  Sets or clears the map's minimum zoom level.
  ///  If the map's current zoom level is lower than the new minimum,
  ///  the map will zoom to the new minimum.
  ///
  ///  It is not always possible to zoom out and reach the set `minZoom`.
  ///  Other factors such as map height may restrict zooming. For example,
  ///  if the map is 512px tall it will not be possible to zoom below zoom 0
  ///  no matter what the `minZoom` is set to.
  ///
  ///  @param {number | null | undefined} minZoom The minimum zoom level to set (-2 - 24).
  ///    If `null` or `undefined` is provided, the function removes the current minimum zoom (i.e. sets it to -2).
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  map.setMinZoom(12.25);
  MapLibreMap setMinZoom([num? minZoom]) =>
      MapLibreMap.fromJsObject(jsObject.setMinZoom(minZoom));

  ///  Returns the map's minimum allowable zoom level.
  ///
  ///  @returns {number} minZoom
  ///  @example
  ///  var minZoom = map.getMinZoom();
  num getMinZoom() => jsObject.getMinZoom();

  ///  Sets or clears the map's maximum zoom level.
  ///  If the map's current zoom level is higher than the new maximum,
  ///  the map will zoom to the new maximum.
  ///
  ///  @param {number | null | undefined} maxZoom The maximum zoom level to set.
  ///    If `null` or `undefined` is provided, the function removes the current maximum zoom (sets it to 22).
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  map.setMaxZoom(18.75);
  MapLibreMap setMaxZoom([num? maxZoom]) =>
      MapLibreMap.fromJsObject(jsObject.setMaxZoom(maxZoom));

  ///  Returns the map's maximum allowable zoom level.
  ///
  ///  @returns {number} maxZoom
  ///  @example
  ///  var maxZoom = map.getMaxZoom();
  num getMaxZoom() => jsObject.getMaxZoom();

  ///  Sets or clears the map's minimum pitch.
  ///  If the map's current pitch is lower than the new minimum,
  ///  the map will pitch to the new minimum.
  ///
  ///  @param {number | null | undefined} minPitch The minimum pitch to set (0-60).
  ///    If `null` or `undefined` is provided, the function removes the current minimum pitch (i.e. sets it to 0).
  ///  @returns {MapLibreMap} `this`
  MapLibreMap setMinPitch([num? minPitch]) =>
      MapLibreMap.fromJsObject(jsObject.setMinPitch());

  ///  Returns the map's minimum allowable pitch.
  ///
  ///  @returns {number} minPitch
  num getMinPitch() => jsObject.getMinPitch();

  ///  Sets or clears the map's maximum pitch.
  ///  If the map's current pitch is higher than the new maximum,
  ///  the map will pitch to the new maximum.
  ///
  ///  @param {number | null | undefined} maxPitch The maximum pitch to set.
  ///    If `null` or `undefined` is provided, the function removes the current maximum pitch (sets it to 60).
  ///  @returns {MapLibreMap} `this`
  MapLibreMap setMaxPitch([num? maxPitch]) =>
      MapLibreMap.fromJsObject(jsObject.setMaxPitch());

  ///  Returns the map's maximum allowable pitch.
  ///
  ///  @returns {number} maxPitch
  num getMaxPitch() => jsObject.getMaxPitch();

  ///  Returns the state of `renderWorldCopies`. If `true`, multiple copies of the world will be rendered side by side beyond -180 and 180 degrees longitude. If set to `false`:
  ///  - When the map is zoomed out far enough that a single representation of the world does not fill the map's entire
  ///  container, there will be blank space beyond 180 and -180 degrees longitude.
  ///  - Features that cross 180 and -180 degrees longitude will be cut in two (with one portion on the right edge of the
  ///  map and the other on the left edge of the map) at every zoom level.
  ///  @returns {boolean} renderWorldCopies
  ///  @example
  ///  var worldCopiesRendered = map.getRenderWorldCopies();
  ///  @see [Render world copies](https://maplibre.org/maplibre-gl-js/docs/examples/render-world-copies/)
  bool getRenderWorldCopies() => jsObject.getRenderWorldCopies();

  ///  Sets the state of `renderWorldCopies`.
  ///
  ///  @param {boolean} renderWorldCopies If `true`, multiple copies of the world will be rendered side by side beyond -180 and 180 degrees longitude. If set to `false`:
  ///  - When the map is zoomed out far enough that a single representation of the world does not fill the map's entire
  ///  container, there will be blank space beyond 180 and -180 degrees longitude.
  ///  - Features that cross 180 and -180 degrees longitude will be cut in two (with one portion on the right edge of the
  ///  map and the other on the left edge of the map) at every zoom level.
  ///
  ///  `undefined` is treated as `true`, `null` is treated as `false`.
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  map.setRenderWorldCopies(true);
  ///  @see [Render world copies](https://maplibre.org/maplibre-gl-js/docs/examples/render-world-copies/)
  MapLibreMap setRenderWorldCopies([bool? renderWorldCopies]) =>
      MapLibreMap.fromJsObject(
          jsObject.setRenderWorldCopies(renderWorldCopies));

  ///  Returns a {@link Point} representing pixel coordinates, relative to the map's `container`,
  ///  that correspond to the specified geographical location.
  ///
  ///  @param {LngLatLike} lnglat The geographical location to project.
  ///  @returns {Point} The {@link Point} corresponding to `lnglat`, relative to the map's `container`.
  ///  @example
  ///  var coordinate = [-122.420679, 37.772537];
  ///  var point = map.project(coordinate);
  Point project(LngLat lnglat) =>
      Point.fromJsObject(jsObject.project(lnglat.jsObject));

  ///  Returns a {@link LngLat} representing geographical coordinates that correspond
  ///  to the specified pixel coordinates.
  ///
  ///  @param {PointLike} point The pixel coordinates to unproject.
  ///  @returns {LngLat} The {@link LngLat} corresponding to `point`.
  ///  @example
  ///  map.on('click', function(e) {
  ///    // When the map is clicked, get the geographic coordinate.
  ///    var coordinate = map.unproject(e.point);
  ///  });
  LngLat unproject(Point point) =>
      LngLat.fromJsObject(jsObject.unproject(point.jsObject));

  ///  Returns true if the map is panning, zooming, rotating, or pitching due to a camera animation or user gesture.
  ///  @example
  ///  var isMoving = map.isMoving();
  bool isMoving() => jsObject.isMoving();

  ///  Returns true if the map is zooming due to a camera animation or user gesture.
  ///  @example
  ///  var isZooming = map.isZooming();
  bool isZooming() => jsObject.isZooming();

  ///  Returns true if the map is rotating due to a camera animation or user gesture.
  ///  @example
  ///  map.isRotating();
  bool isRotating() => jsObject.isRotating();

  ///  Adds a listener for events of a specified type occurring on features in a specified style layer.
  ///
  ///  @param {string} type The event type to listen for; one of `'mousedown'`, `'mouseup'`, `'click'`, `'dblclick'`,
  ///  `'mousemove'`, `'mouseenter'`, `'mouseleave'`, `'mouseover'`, `'mouseout'`, `'contextmenu'`, `'touchstart'`,
  ///  `'touchend'`, or `'touchcancel'`. `mouseenter` and `mouseover` events are triggered when the cursor enters
  ///  a visible portion of the specified layer from outside that layer or outside the map canvas. `mouseleave`
  ///  and `mouseout` events are triggered when the cursor leaves a visible portion of the specified layer, or leaves
  ///  the map canvas.
  ///  @param {string} layerId The ID of a style layer. Only events whose location is within a visible
  ///  feature in this layer will trigger the listener. The event will have a `features` property containing
  ///  an array of the matching features.
  ///  @param {Function} listener The function to be called when the event is fired.
  ///  @returns {MapLibreMap} `this`
  // Defined in evented.dart
  // MapLibreMap on(String type, [dynamic layerIdOrListener, Listener listener]);

  ///  Removes an event listener for layer-specific events previously added with `MapLibreMap#on`.
  ///
  ///  @param {string} type The event type previously used to install the listener.
  ///  @param {string} layerId The layer ID previously used to install the listener.
  ///  @param {Function} listener The function previously installed as a listener.
  ///  @returns {MapLibreMap} `this`
  // Defined in evented.dart
  // MapLibreMap off(String type, [dynamic layerIdOrListener, Listener listener]);

  ///  Returns an array of [GeoJSON](http://geojson.org/)
  ///  [Feature objects](https://tools.ietf.org/html/rfc7946#section-3.2)
  ///  representing visible features that satisfy the query parameters.
  ///
  ///  @param {PointLike|Array<PointLike>} [geometry] - The geometry of the query region:
  ///  either a single point or southwest and northeast points describing a bounding box.
  ///  Omitting this parameter (i.e. calling {@link MapLibreMap#queryRenderedFeatures} with zero arguments,
  ///  or with only a [options] argument) is equivalent to passing a bounding box encompassing the entire
  ///  map viewport.
  ///  @param {Object} [options]
  ///  @param {Array<string>} `options.layers` An array of [style layer IDs](https://maplibre.org/maplibre-style-spec/#layer-id) for the query to inspect.
  ///    Only features within these layers will be returned. If this parameter is undefined, all layers will be checked.
  ///  @param {Array} `options.filter` A [filter](https://maplibre.org/maplibre-style-spec/#other-filter)
  ///    to limit query results.
  ///  @param {boolean} [options.validate=true] Whether to check if the `options.filter` conforms to the MapLibre JS Style Specification. Disabling validation is a performance optimization that should only be used if you have previously validated the values you will be passing to this function.
  ///
  ///  @returns {Array<Object>} An array of [GeoJSON](http://geojson.org/)
  ///  [feature objects](https://tools.ietf.org/html/rfc7946#section-3.2).
  ///
  ///  The `properties` value of each returned feature object contains the properties of its source feature. For GeoJSON sources, only
  ///  string and numeric property values are supported (i.e. `null`, `Array`, and `Object` values are not supported).
  ///
  ///  Each feature includes top-level `layer`, `source`, and `sourceLayer` properties. The `layer` property is an object
  ///  representing the style layer to  which the feature belongs. Layout and paint properties in this object contain values
  ///  which are fully evaluated for the given zoom level and feature.
  ///
  ///  Only features that are currently rendered are included. Some features will////// not** be included, like:
  ///
  ///  - Features from layers whose `visibility` property is `"none"`.
  ///  - Features from layers whose zoom range excludes the current zoom level.
  ///  - Symbol features that have been hidden due to text or icon collision.
  ///
  ///  Features from all other layers are included, including features that may have no visible
  ///  contribution to the rendered result; for example, because the layer's opacity or color alpha component is set to
  ///  0.
  ///
  ///  The topmost rendered feature appears first in the returned array, and subsequent features are sorted by
  ///  descending z-order. Features that are rendered multiple times (due to wrapping across the antimeridian at low
  ///  zoom levels) are returned only once (though subject to the following caveat).
  ///
  ///  Because features come from tiled vector data or GeoJSON data that is converted to tiles internally, feature
  ///  geometries may be split or duplicated across tile boundaries and, as a result, features may appear multiple
  ///  times in query results. For example, suppose there is a highway running through the bounding rectangle of a query.
  ///  The results of the query will be those parts of the highway that lie within the map tiles covering the bounding
  ///  rectangle, even if the highway extends into other tiles, and the portion of the highway within each map tile
  ///  will be returned as a separate feature. Similarly, a point feature near a tile boundary may appear in multiple
  ///  tiles due to tile buffering.
  ///
  ///  @example
  ///  // Find all features at a point
  ///  var features = map.queryRenderedFeatures(
  ///    [20, 35],
  ///    { layers: ['my-layer-name'] }
  ///  );
  ///
  ///  @example
  ///  // Find all features within a static bounding box
  ///  var features = map.queryRenderedFeatures(
  ///    [[10, 20], [30, 50]],
  ///    { layers: ['my-layer-name'] }
  ///  );
  ///
  ///  @example
  ///  // Find all features within a bounding box around a point
  ///  var width = 10;
  ///  var height = 20;
  ///  var features = map.queryRenderedFeatures([
  ///    [point.x - width / 2, point.y - height / 2],
  ///    [point.x + width / 2, point.y + height / 2]
  ///  ], { layers: ['my-layer-name'] });
  ///
  ///  @example
  ///  // Query all rendered features from a single layer
  ///  var features = map.queryRenderedFeatures({ layers: ['my-layer-name'] });
  ///  @see [Get features under the mouse pointer](https://maplibre.org/maplibre-gl-js/docs/examples/queryrenderedfeatures/)
  ///  @see [Highlight features within a bounding box](https://maplibre.org/maplibre-gl-js/docs/examples/using-box-queryrenderedfeatures/)
  ///  @see [Filter features within map view](https://maplibre.org/maplibre-gl-js/docs/examples/filter-features-within-map-view/)
  List<Feature> queryRenderedFeatures(dynamic geometry,
      [Map<String, dynamic>? options]) {
    if (options == null) {
      return jsObject
          .queryRenderedFeatures(geometry)
          .map((dynamic f) => Feature.fromJsObject(f))
          .toList();
    }
    return jsObject
        .queryRenderedFeatures(geometry, jsify(options))
        .map((dynamic f) => Feature.fromJsObject(f))
        .toList();
  }

  ///  Returns an array of [GeoJSON](http://geojson.org/)
  ///  [Feature objects](https://tools.ietf.org/html/rfc7946#section-3.2)
  ///  representing features within the specified vector tile or GeoJSON source that satisfy the query parameters.
  ///
  ///  @param {string} sourceId The ID of the vector tile or GeoJSON source to query.
  ///  @param {Object} [parameters]
  ///  @param {string} `parameters.sourceLayer` The name of the [source layer]
  ///    to query./// For vector tile sources, this parameter is required.* For GeoJSON sources, it is ignored.
  ///  @param {Array} `parameters.filter` A [filter](https://maplibre.org/maplibre-style-spec/#other-filter)
  ///    to limit query results.
  ///  @param {boolean} `parameters.validate=true` Whether to check if the `parameters.filter` conforms to the MapLibre JS Style Specification. Disabling validation is a performance optimization that should only be used if you have previously validated the values you will be passing to this function.
  ///
  ///  @returns {Array<Object>} An array of [GeoJSON](http://geojson.org/)
  ///  [Feature objects](https://tools.ietf.org/html/rfc7946#section-3.2).
  ///
  ///  In contrast to {@link MapLibreMap#queryRenderedFeatures}, this function returns all features matching the query parameters,
  ///  whether or not they are rendered by the current style (i.e. visible). The domain of the query includes all currently-loaded
  ///  vector tiles and GeoJSON source tiles: this function does not check tiles outside the currently
  ///  visible viewport.
  ///
  ///  Because features come from tiled vector data or GeoJSON data that is converted to tiles internally, feature
  ///  geometries may be split or duplicated across tile boundaries and, as a result, features may appear multiple
  ///  times in query results. For example, suppose there is a highway running through the bounding rectangle of a query.
  ///  The results of the query will be those parts of the highway that lie within the map tiles covering the bounding
  ///  rectangle, even if the highway extends into other tiles, and the portion of the highway within each map tile
  ///  will be returned as a separate feature. Similarly, a point feature near a tile boundary may appear in multiple
  ///  tiles due to tile buffering.
  ///
  ///  @example
  ///  // Find all features in one source layer in a vector source
  ///  var features = map.querySourceFeatures('your-source-id', {
  ///    sourceLayer: 'your-source-layer'
  ///  });
  ///
  ///  @see [Highlight features containing similar data](https://maplibre.org/maplibre-gl-js/docs/examples/query-similar-features/)
  List<dynamic> querySourceFeatures(String sourceId, dynamic parameters) =>
      jsObject.querySourceFeatures(sourceId, parameters);

  ///  Updates the map's MapLibre style object with a new value.
  ///
  ///  If a style is already set when this is used and options.diff is set to true, the map renderer will attempt to compare the given style
  ///  against the map's current state and perform only the changes necessary to make the map style match the desired state. Changes in sprites
  ///  (images used for icons and patterns) and glyphs (fonts for label text)////// cannot** be diffed. If the sprites or fonts used in the current
  ///  style and the given style are different in any way, the map renderer will force a full update, removing the current style and building
  ///  the given one from scratch.
  ///
  ///
  ///  @param style A JSON object conforming to the schema described in the
  ///    [MapLibre Style Specification](https://maplibre.org/maplibre-style-spec/), or a URL to such JSON.
  ///  @param {Object} [options]
  ///  @param {boolean} [options.diff=true] If false, force a 'full' update, removing the current style
  ///    and building the given one instead of attempting a diff-based update.
  ///  @param {string} [options.localIdeographFontFamily='sans-serif'] Defines a CSS
  ///    font-family for locally overriding generation of glyphs in the 'CJK Unified Ideographs', 'Hiragana', 'Katakana' and 'Hangul Syllables' ranges.
  ///    In these ranges, font settings from the map's style will be ignored, except for font-weight keywords (light/regular/medium/bold).
  ///    Set to `false`, to enable font settings from the map's style for these glyph ranges.
  ///    Forces a full update.
  ///  @returns {MapLibreMap} `this`
  ///  @see [Change a map's style](https://maplibre.org/maplibre-gl-js/docs/examples/setstyle/)
  MapLibreMap setStyle(dynamic style, [dynamic options]) =>
      MapLibreMap.fromJsObject(jsObject.setStyle(style));

  ///  Returns the map's MapLibre style object, which can be used to recreate the map's style.
  ///
  ///  @returns {Object} The map's style object.
  ///
  ///  @example
  ///  var styleJson = map.getStyle();
  dynamic getStyle() => jsObject.getStyle();

  /// Return each layer of the  MapLibre style object, which can be used to check the order, toggle the visibility or change properties
  List<dynamic> getLayers() => Style.fromJsObject(jsObject.getStyle()).layers;

  ///  Returns a Boolean indicating whether the map's style is fully loaded.
  ///
  ///  @returns {boolean} A Boolean indicating whether the style is fully loaded.
  ///
  ///  @example
  ///  var styleLoadStatus = map.isStyleLoaded();
  bool isStyleLoaded() => jsObject.isStyleLoaded();

  ///  Adds a source to the map's style.
  ///
  ///  @param {string} id The ID of the source to add. Must not conflict with existing sources.
  ///  @param {Object} source The source object, conforming to the
  ///  MapLibre Style Specification's [source definition](https://maplibre.org/maplibre-style-spec/#sources) or
  ///  {@link CanvasSourceOptions}.
  ///  @fires source.add
  ///  @returns {MapLibreMap} `this`
  ///  });
  ///  @see Vector source: [Show and hide layers](https://maplibre.org/maplibre-gl-js/docs/examples/toggle-layers/)
  ///  @see GeoJSON source: [Add live realtime data](https://maplibre.org/maplibre-gl-js/docs/examples/live-geojson/)
  ///  @see Raster DEM source: [Add hillshading](https://maplibre.org/maplibre-gl-js/docs/examples/hillshade/)
  MapLibreMap addSource(String id, dynamic source) {
    if (source is Source) {
      return MapLibreMap.fromJsObject(jsObject.addSource(id, source.jsObject));
    }
    return MapLibreMap.fromJsObject(jsObject.addSource(id, jsify(source)));
  }

  ///  Returns a Boolean indicating whether the source is loaded.
  ///
  ///  @param {string} id The ID of the source to be checked.
  ///  @returns {boolean} A Boolean indicating whether the source is loaded.
  ///  @example
  ///  var sourceLoaded = map.isSourceLoaded('bathymetry-data');
  bool isSourceLoaded(String id) => jsObject.isSourceLoaded(id);

  ///  Returns a Boolean indicating whether all tiles in the viewport from all sources on
  ///  the style are loaded.
  ///
  ///  @returns {boolean} A Boolean indicating whether all tiles are loaded.
  ///  @example
  ///  var tilesLoaded = map.areTilesLoaded();
  bool areTilesLoaded() => jsObject.areTilesLoaded();

  ///  Adds a/// *custom source type**(#Custom Sources), making it available for use with
  ///  {@link MapLibreMap#addSource}.
  ///  @private
  ///  @param {string} name The name of the source type; source definition objects use this name in the `{type: ...}` field.
  ///  @param {Function} SourceType A {@link Source} constructor.
  ///  @param {Function} callback Called when the source type is ready or with an error argument if there is an error.
  addSourceType(String name, dynamic sourceType, Function callback) =>
      jsObject.addSourceType(name, sourceType, callback);

  ///  Removes a source from the map's style.
  ///
  ///  @param {string} id The ID of the source to remove.
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  map.removeSource('bathymetry-data');
  removeSource(String id) => jsObject.removeSource(id);

  ///  Returns the source with the specified ID in the map's style.
  ///
  ///  @param {string} id The ID of the source to get.
  ///  @returns {?Object} The style source with the specified ID, or `undefined`
  ///    if the ID corresponds to no existing sources.
  ///  @example
  ///  var sourceObject = map.getSource('points');
  ///  @see [Create a draggable point](https://maplibre.org/maplibre-gl-js/docs/examples/drag-a-point/)
  ///  @see [Animate a point](https://maplibre.org/maplibre-gl-js/docs/examples/animate-point-along-line/)
  ///  @see [Add live realtime data](https://maplibre.org/maplibre-gl-js/docs/examples/live-geojson/)
  dynamic getSource(String id) {
    var source = jsObject.getSource(id);
    if (source is GeoJsonSourceJsImpl) {
      return GeoJsonSource.fromJsObject(source);
    }
    if (source is VectorSourceJsImpl) {
      return VectorSource.fromJsObject(source);
    }
    return source;
  }

  ///  Add an image to the style. This image can be displayed on the map like any other icon in the style's
  ///  [sprite]  using the image's ID with
  ///  [`icon-image`](https://maplibre.org/maplibre-style-spec/#layout-symbol-icon-image),
  ///  [`background-pattern`](https://maplibre.org/maplibre-style-spec/#paint-background-background-pattern),
  ///  [`fill-pattern`](https://maplibre.org/maplibre-style-spec/#paint-fill-fill-pattern),
  ///  or [`line-pattern`](https://maplibre.org/maplibre-style-spec/#paint-line-line-pattern).
  ///  A {@link MapLibreMap#error} event will be fired if there is not enough space in the sprite to add this image.
  ///
  ///  @param id The ID of the image.
  ///  @param image The image as an `HTMLImageElement`, `ImageData`, or object with `width`, `height`, and `data`
  ///  properties with the same format as `ImageData`.
  ///  @param options
  ///  @param options.pixelRatio The ratio of pixels in the image to physical pixels on the screen
  ///  @param options.sdf Whether the image should be interpreted as an SDF image
  ///  @param options.content  `[x1, y1, x2, y2]`  If `icon-text-fit` is used in a layer with this image, this option defines the part of the image that can be covered by the content in `text-field`.
  ///  @param options.stretchX  `[[x1, x2], ...]` If `icon-text-fit` is used in a layer with this image, this option defines the part(s) of the image that can be stretched horizontally.
  ///  @param options.stretchY  `[[y1, y2], ...]` If `icon-text-fit` is used in a layer with this image, this option defines the part(s) of the image that can be stretched vertically.
  ///
  ///  @example
  ///  // If the style's sprite does not already contain an image with ID 'cat',
  ///  // add the image 'cat-icon.png' to the style's sprite with the ID 'cat'.
  ///  map.loadImage('https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Cat_silhouette.svg/400px-Cat_silhouette.svg.png', function(error, image) {
  ///     if (error) throw error;
  ///     if (!map.hasImage('cat')) map.addImage('cat', image);
  ///  });
  ///
  ///
  ///  // Add a stretchable image that can be used with `icon-text-fit`
  ///  // In this example, the image is 600px wide by 400px high.
  ///  map.loadImage('https://upload.wikimedia.org/wikipedia/commons/8/89/Black_and_White_Boxed_%28bordered%29.png', function(error, image) {
  ///     if (error) throw error;
  ///     if (!map.hasImage('border-image')) {
  ///       map.addImage('border-image', image, {
  ///           content: [16, 16, 300, 384], // place text over left half of image, avoiding the 16px border
  ///           stretchX: [[16, 584]], // stretch everything horizontally except the 16px border
  ///           stretchY: [[16, 384]], // stretch everything vertically except the 16px border
  ///       });
  ///     }
  ///  });
  ///
  ///
  ///  @see Use `HTMLImageElement`: [Add an icon to the map](https://maplibre.org/maplibre-gl-js/docs/examples/add-image/)
  ///  @see Use `ImageData`: [Add a generated icon to the map](https://maplibre.org/maplibre-gl-js/docs/examples/add-image-generated/)
  addImage(String id, dynamic image, [Map<String, dynamic>? options]) {
    if (image is Map) {
      image = jsify(image);
    }
    return options == null
        ? jsObject.addImage(id, image)
        : jsObject.addImage(id, image, jsify(options));
  }

  ///  Update an existing image in a style. This image can be displayed on the map like any other icon in the style's
  ///  [sprite]  using the image's ID with
  ///  [`icon-image`](https://maplibre.org/maplibre-style-spec/#layout-symbol-icon-image),
  ///  [`background-pattern`](https://maplibre.org/maplibre-style-spec/#paint-background-background-pattern),
  ///  [`fill-pattern`](https://maplibre.org/maplibre-style-spec/#paint-fill-fill-pattern),
  ///  or [`line-pattern`](https://maplibre.org/maplibre-style-spec/#paint-line-line-pattern).
  ///
  ///  @param id The ID of the image.
  ///  @param image The image as an `HTMLImageElement`, `ImageData`, or object with `width`, `height`, and `data`
  ///  properties with the same format as `ImageData`.
  ///
  ///  @example
  ///  // If an image with the ID 'cat' already exists in the style's sprite,
  ///  // replace that image with a new image, 'other-cat-icon.png'.
  ///  if (map.hasImage('cat')) map.updateImage('cat', './other-cat-icon.png');
  updateImage(String id, dynamic image) => jsObject.updateImage(id, image);

  ///  Check whether or not an image with a specific ID exists in the style. This checks both images
  ///  in the style's original [sprite]  and any images
  ///  that have been added at runtime using {@link addImage}.
  ///
  ///  @param id The ID of the image.
  ///
  ///  @returns {boolean}  A Boolean indicating whether the image exists.
  ///  @example
  ///  // Check if an image with the ID 'cat' exists in
  ///  // the style's sprite.
  ///  var catIconExists = map.hasImage('cat');
  bool hasImage(String id) => jsObject.hasImage(id);

  ///  Remove an image from a style. This can be an image from the style's original
  ///  [sprite]  or any images
  ///  that have been added at runtime using {@link addImage}.
  ///
  ///  @param id The ID of the image.
  ///
  ///  @example
  ///  // If an image with the ID 'cat' exists in
  ///  // the style's sprite, remove it.
  ///  if (map.hasImage('cat')) map.removeImage('cat');
  removeImage(String id) => jsObject.removeImage(id);

  ///  Load an image from an external URL to be used with `MapLibreMap#addImage`. External
  ///  domains must support [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS).
  ///
  ///  @param {string} url The URL of the image file. Image file must be in png, webp, or jpg format.
  ///  @param {Function} callback Expecting `callback(error, data)`. Called when the image has loaded or with an error argument if there is an error.
  ///
  ///  @example
  ///  // Load an image from an external URL.
  ///  map.loadImage('http://placekitten.com/50/50', function(error, image) {
  ///    if (error) throw error;
  ///    // Add the loaded image to the style's sprite with the ID 'kitten'.
  ///    map.addImage('kitten', image);
  ///  });
  ///
  ///  @see [Add an icon to the map](https://maplibre.org/maplibre-gl-js/docs/examples/add-image/)
  loadImage(String url, Function callback) =>
      jsObject.loadImage(url, allowInterop(callback));

  //////
  ///  Returns an Array of strings containing the IDs of all images currently available in the map.
  ///  This includes both images from the style's original [sprite]
  ///  and any images that have been added at runtime using {@link addImage}.
  ///
  ///  @returns {Array<string>} An Array of strings containing the names of all sprites/images currently available in the map.
  ///
  ///  @example
  ///  var allImages = map.listImages();
  ///
  List<String> listImages() => jsObject.listImages();

  ///  Adds a [MapLibre style layer](https://maplibre.org/maplibre-style-spec/#layers)
  ///  to the map's style.
  ///
  ///  A layer defines how data from a specified source will be styled. Read more about layer types
  ///  and available paint and layout properties in the [MapLibre Style Specification](https://maplibre.org/maplibre-style-spec/#layers).
  ///
  ///  @param {Object | CustomLayerInterface} layer The style layer to add, conforming to the MapLibre Style Specification's
  ///    [layer definition](https://maplibre.org/maplibre-style-spec/#layers).
  ///  @param {string} [beforeId] The ID of an existing layer to insert the new layer before.
  ///    If this argument is omitted, the layer will be appended to the end of the layers array.
  ///
  ///  @returns {MapLibreMap} `this`
  ///
  ///  @see [Create and style clusters](https://maplibre.org/maplibre-gl-js/docs/examples/cluster/)
  ///  @see [Add a vector tile source](https://maplibre.org/maplibre-gl-js/docs/examples/vector-source/)
  ///  @see [Add a WMS source](https://maplibre.org/maplibre-gl-js/docs/examples/wms/)
  MapLibreMap addLayer(dynamic layer, [String? beforeId]) {
    if (layer is Layer) {
      return MapLibreMap.fromJsObject(
          jsObject.addLayer(layer.jsObject, beforeId));
    }
    return MapLibreMap.fromJsObject(jsObject.addLayer(jsify(layer), beforeId));
  }

  //jsObject.addLayer(layer.jsObject ?? jsify(layer));

  ///  Moves a layer to a different z-position.
  ///
  ///  @param {string} id The ID of the layer to move.
  ///  @param {string} [beforeId] The ID of an existing layer to insert the new layer before.
  ///    If this argument is omitted, the layer will be appended to the end of the layers array.
  ///  @returns {MapLibreMap} `this`
  ///
  ///  @example
  ///  // Move a layer with ID 'label' before the layer with ID 'waterways'.
  ///  map.moveLayer('label', 'waterways');
  MapLibreMap moveLayer(String id, String beforeId) =>
      MapLibreMap.fromJsObject(jsObject.moveLayer(id, beforeId));

  ///  Removes the layer with the given ID from the map's style.
  ///
  ///  If no such layer exists, an `error` event is fired.
  ///
  ///  @param {string} id id of the layer to remove
  ///  @fires error
  ///
  ///  @example
  ///  // If a layer with ID 'state-data' exists, remove it.
  ///  if (map.getLayer('state-data')) map.removeLayer('state-data');
  removeLayer(String id) => jsObject.removeLayer(id);

  ///  Returns the layer with the specified ID in the map's style.
  ///
  ///  @param {string} id The ID of the layer to get.
  ///  @returns {?Object} The layer with the specified ID, or `undefined`
  ///    if the ID corresponds to no existing layers.
  ///
  ///  @example
  ///  var stateDataLayer = map.getLayer('state-data');
  ///
  ///  @see [Filter symbols by toggling a list](https://maplibre.org/maplibre-gl-js/docs/examples/filter-markers/)
  ///  @see [Filter symbols by text input](https://maplibre.org/maplibre-gl-js/docs/examples/filter-markers-by-input/)
  dynamic getLayer(String id) => jsObject.getLayer(id);

  ///  Sets the zoom extent for the specified style layer. The zoom extent includes the
  ///  [minimum zoom level](https://maplibre.org/maplibre-style-spec/#layer-minzoom)
  ///  and [maximum zoom level](https://maplibre.org/maplibre-style-spec/#layer-maxzoom))
  ///  at which the layer will be rendered.
  ///
  ///  Note: For style layers using vector sources, style layers cannot be rendered at zoom levels lower than the
  ///  minimum zoom level of the _source layer_ because the data does not exist at those zoom levels. If the minimum
  ///  zoom level of the source layer is higher than the minimum zoom level defined in the style layer, the style
  ///  layer will not be rendered at all zoom levels in the zoom range.
  ///
  ///  @param {string} layerId The ID of the layer to which the zoom extent will be applied.
  ///  @param {number} minzoom The minimum zoom to set (0-24).
  ///  @param {number} maxzoom The maximum zoom to set (0-24).
  ///  @returns {MapLibreMap} `this`
  ///
  ///  @example
  ///  map.setLayerZoomRange('my-layer', 2, 5);
  MapLibreMap setLayerZoomRange(String layerId, num minzoom, num maxzoom) =>
      MapLibreMap.fromJsObject(
          jsObject.setLayerZoomRange(layerId, minzoom, maxzoom));

  ///  Sets the filter for the specified style layer.
  ///
  ///  @param {string} layerId The ID of the layer to which the filter will be applied.
  ///  @param {Array | null | undefined} filter The filter, conforming to the MapLibre Style Specification's
  ///    [filter definition](https://maplibre.org/maplibre-style-spec/#other-filter).  If `null` or `undefined` is provided, the function removes any existing filter from the layer.
  ///  @param {Object} [options]
  ///  @param {boolean} [options.validate=true] Whether to check if the filter conforms to the MapLibre JS Style Specification. Disabling validation is a performance optimization that should only be used if you have previously validated the values you will be passing to this function.
  ///
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  map.setFilter('my-layer', ['==', 'name', 'USA']);
  ///
  ///  @see [Filter features within map view](https://maplibre.org/maplibre-gl-js/docs/examples/filter-features-within-map-view/)
  ///  @see [Highlight features containing similar data](https://maplibre.org/maplibre-gl-js/docs/examples/query-similar-features/)
  ///  @see [Create a timeline animation](https://maplibre.org/maplibre-gl-js/docs/examples/timeline-animation/)
  MapLibreMap setFilter(String layerId, dynamic filter,
          [StyleSetterOptions? options]) =>
      MapLibreMap.fromJsObject(jsObject.setFilter(layerId, filter));

  ///  Returns the filter applied to the specified style layer.
  ///
  ///  @param {string} layerId The ID of the style layer whose filter to get.
  ///  @returns {Array} The layer's filter.
  List<dynamic> getFilter(String layerId) => jsObject.getFilter(layerId);

  ///  Sets the value of a paint property in the specified style layer.
  ///
  ///  @param {string} layerId The ID of the layer to set the paint property in.
  ///  @param {string} name The name of the paint property to set.
  ///  @param {*} value The value of the paint property to set.
  ///    Must be of a type appropriate for the property, as defined in the [MapLibre Style Specification](https://maplibre.org/maplibre-style-spec/).
  ///  @param {Object} [options]
  ///  @param {boolean} [options.validate=true] Whether to check if `value` conforms to the MapLibre JS Style Specification. Disabling validation is a performance optimization that should only be used if you have previously validated the values you will be passing to this function.
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  map.setPaintProperty('my-layer', 'fill-color', '#faafee');
  ///  @see [Change a layer's color with buttons](https://maplibre.org/maplibre-gl-js/docs/examples/color-switcher/)
  ///  @see [Adjust a layer's opacity](https://maplibre.org/maplibre-gl-js/docs/examples/adjust-layer-opacity/)
  ///  @see [Create a draggable point](https://maplibre.org/maplibre-gl-js/docs/examples/drag-a-point/)
  setPaintProperty(String layerId, String name, dynamic value,
          [StyleSetterOptions? options]) =>
      jsObject.setPaintProperty(layerId, name, jsify(value));

  ///  Returns the value of a paint property in the specified style layer.
  ///
  ///  @param {string} layerId The ID of the layer to get the paint property from.
  ///  @param {string} name The name of a paint property to get.
  ///  @returns {*} The value of the specified paint property.
  dynamic getPaintProperty(String layerId, String name) =>
      jsObject.getPaintProperty(layerId, name);

  ///  Sets the value of a layout property in the specified style layer.
  ///
  ///  @param {string} layerId The ID of the layer to set the layout property in.
  ///  @param {string} name The name of the layout property to set.
  ///  @param {*} value The value of the layout property. Must be of a type appropriate for the property, as defined in the [MapLibre Style Specification](https://maplibre.org/maplibre-style-spec/).
  ///  @param {Object} [options]
  ///  @param {boolean} [options.validate=true] Whether to check if `value` conforms to the MapLibre JS Style Specification. Disabling validation is a performance optimization that should only be used if you have previously validated the values you will be passing to this function.
  ///  @returns {MapLibreMap} `this`
  ///  @example
  ///  map.setLayoutProperty('my-layer', 'visibility', 'none');
  MapLibreMap setLayoutProperty(String layerId, String name, dynamic value,
          [StyleSetterOptions? options]) =>
      MapLibreMap.fromJsObject(
          jsObject.setLayoutProperty(layerId, name, value));

  ///  Returns the value of a layout property in the specified style layer.
  ///
  ///  @param {string} layerId The ID of the layer to get the layout property from.
  ///  @param {string} name The name of the layout property to get.
  ///  @returns {*} The value of the specified layout property.
  dynamic getLayoutProperty(String layerId, String name) =>
      jsObject.getLayoutProperty(layerId, name);

  ///  Sets the any combination of light values.
  ///
  ///  @param light Light properties to set. Must conform to the [MapLibre Style Specification](https://maplibre.org/maplibre-style-spec/#light).
  ///  @param {Object} [options]
  ///  @param {boolean} [options.validate=true] Whether to check if the filter conforms to the MapLibre JS Style Specification. Disabling validation is a performance optimization that should only be used if you have previously validated the values you will be passing to this function.
  ///  @returns {MapLibreMap} `this`
  MapLibreMap setLight(dynamic light, StyleSetterOptions options) =>
      MapLibreMap.fromJsObject(jsObject.setLight(light, options.jsObject));

  ///  Returns the value of the light object.
  ///
  ///  @returns {Object} light Light properties of the style.
  dynamic getLight() => jsObject.getLight();

  ///  Sets the state of a feature. The `state` object is merged in with the existing state of the feature.
  ///  Features are identified by their `id` attribute, which must be an integer or a string that can be
  ///  cast to an integer.
  ///
  ///  @param {Object} feature Feature identifier. Feature objects returned from
  ///  {@link MapLibreMap#queryRenderedFeatures} or event handlers can be used as feature identifiers.
  ///  @param {string | number} feature.id Unique id of the feature.
  ///  @param {string} feature.source The Id of the vector source or GeoJSON source for the feature.
  ///  @param {string} `feature.sourceLayer` (optional) /// For vector tile sources, the sourceLayer is
  ///   required.*
  ///  @param {Object} state A set of key-value pairs. The values should be valid JSON types.
  ///
  ///  This method requires the `feature.id` attribute on data sets. For GeoJSON sources without
  ///  feature ids, set the `generateId` option in the `GeoJSONSourceSpecification` to auto-assign them. This
  ///  option assigns ids based on a feature's index in the source data. If you change feature data using
  ///  `map.getSource('some id').setData(..)`, you may need to re-apply state taking into account updated `id` values.
  setFeatureState(dynamic feature, dynamic state) =>
      jsObject.setFeatureState(feature, state);

  ///  Removes feature state, setting it back to the default behavior. If only
  ///  source is specified, removes all states of that source. If
  ///  target.id is also specified, removes all keys for that feature's state.
  ///  If key is also specified, removes that key from that feature's state.
  ///  Features are identified by their `id` attribute, which must be an integer or a string that can be
  ///  cast to an integer.
  ///  @param {Object} target Identifier of where to set state: can be a source, a feature, or a specific key of feature.
  ///  Feature objects returned from {@link MapLibreMap#queryRenderedFeatures} or event handlers can be used as feature identifiers.
  ///  @param {string | number} target.id (optional) Unique id of the feature. Optional if key is not specified.
  ///  @param {string} target.source The Id of the vector source or GeoJSON source for the feature.
  ///  @param {string} `target.sourceLayer` (optional) /// For vector tile sources, the sourceLayer is
  ///   required.*
  ///  @param {string} key (optional) The key in the feature state to reset.
  removeFeatureState(dynamic target, [String? key]) =>
      jsObject.removeFeatureState(target);

  ///  Gets the state of a feature.
  ///  Features are identified by their `id` attribute, which must be an integer or a string that can be
  ///  cast to an integer.
  ///
  ///  @param {Object} feature Feature identifier. Feature objects returned from
  ///  {@link MapLibreMap#queryRenderedFeatures} or event handlers can be used as feature identifiers.
  ///  @param {string | number} feature.id Unique id of the feature.
  ///  @param {string} feature.source The Id of the vector source or GeoJSON source for the feature.
  ///  @param {string} `feature.sourceLayer` (optional) /// For vector tile sources, the sourceLayer is
  ///   required.*
  ///
  ///  @returns {Object} The state of the feature.
  dynamic getFeatureState(dynamic feature) => jsObject.getFeatureState(feature);

  ///  Returns the map's containing HTML element.
  ///
  ///  @returns {HTMLElement} The map's container.
  HtmlElement getContainer() => jsObject.getContainer();

  ///  Returns the HTML element containing the map's `<canvas>` element.
  ///
  ///  If you want to add non-GL overlays to the map, you should append them to this element.
  ///
  ///  This is the element to which event bindings for map interactivity (such as panning and zooming) are
  ///  attached. It will receive bubbled events from child elements such as the `<canvas>`, but not from
  ///  map controls.
  ///
  ///  @returns {HTMLElement} The container of the map's `<canvas>`.
  ///  @see [Create a draggable point](https://maplibre.org/maplibre-gl-js/docs/examples/drag-a-point/)
  ///  @see [Highlight features within a bounding box](https://maplibre.org/maplibre-gl-js/docs/examples/using-box-queryrenderedfeatures/)
  HtmlElement getCanvasContainer() => jsObject.getCanvasContainer();

  ///  Returns the map's `<canvas>` element.
  ///
  ///  @returns {HTMLCanvasElement} The map's `<canvas>` element.
  ///  @see [Measure distances](https://maplibre.org/maplibre-gl-js/docs/examples/measure/)
  ///  @see [Display a popup on hover](https://maplibre.org/maplibre-gl-js/docs/examples/popup-on-hover/)
  ///  @see [Center the map on a clicked symbol](https://maplibre.org/maplibre-gl-js/docs/examples/center-on-symbol/)
  CanvasElement getCanvas() => jsObject.getCanvas();

  ///  Returns a Boolean indicating whether the map is fully loaded.
  ///
  ///  Returns `false` if the style is not yet fully loaded,
  ///  or if there has been a change to the sources or style that
  ///  has not yet fully loaded.
  ///
  ///  @returns {boolean} A Boolean indicating whether the map is fully loaded.
  bool loaded() => jsObject.loaded();

  ///  Clean up and release all internal resources associated with this map.
  ///
  ///  This includes DOM elements, event bindings, web workers, and WebGL resources.
  ///
  ///  Use this method when you are done using the map and wish to ensure that it no
  ///  longer consumes browser resources. Afterwards, you must not call any other
  ///  methods on the map.
  remove() => jsObject.remove();

  ///  Trigger the rendering of a single frame. Use this method with custom layers to
  ///  repaint the map when the layer changes. Calling this multiple times before the
  ///  next frame is rendered will still result in only a single frame being rendered.
  triggerRepaint() => jsObject.triggerRepaint();

  ///  Gets and sets a Boolean indicating whether the map will render an outline
  ///  around each tile and the tile ID. These tile boundaries are useful for
  ///  debugging.
  ///
  ///  The uncompressed file size of the first vector source is drawn in the top left
  ///  corner of each tile, next to the tile ID.
  ///
  ///  @name showTileBoundaries
  ///  @type {boolean}
  ///  @instance
  ///  @memberof MapLibreMap
  bool get showTileBoundaries => jsObject.showTileBoundaries;

  set showTileBoundaries(bool value) => jsObject.showTileBoundaries;

  ///  Gets and sets a Boolean indicating whether the map will render boxes
  ///  around all symbols in the data source, revealing which symbols
  ///  were rendered or which were hidden due to collisions.
  ///  This information is useful for debugging.
  ///
  ///  @name showCollisionBoxes
  ///  @type {boolean}
  ///  @instance
  ///  @memberof MapLibreMap
  bool get showCollisionBoxes => jsObject.showCollisionBoxes;

  set showCollisionBoxes(bool value) => jsObject.showCollisionBoxes;

  ///  Gets and sets a Boolean indicating whether the map should color-code
  ///  each fragment to show how many times it has been shaded.
  ///  White fragments have been shaded 8 or more times.
  ///  Black fragments have been shaded 0 times.
  ///  This information is useful for debugging.
  ///
  ///  @name showOverdraw
  ///  @type {boolean}
  ///  @instance
  ///  @memberof MapLibreMap
  bool get showOverdrawInspector => jsObject.showOverdrawInspector;

  set showOverdrawInspector(bool value) => jsObject.showOverdrawInspector;

  ///  Gets and sets a Boolean indicating whether the map will
  ///  continuously repaint. This information is useful for analyzing performance.
  ///
  ///  @name repaint
  ///  @type {boolean}
  ///  @instance
  ///  @memberof MapLibreMap
  bool get repaint => jsObject.repaint;

  set repaint(bool value) => jsObject.repaint;

  /// show vertices
  bool get vertices => jsObject.vertices;

  set vertices(bool value) => jsObject.vertices;

  ///  The version of MapLibre JS JS in use as specified in package.json, CHANGELOG.md, and the GitHub release.
  ///
  ///  @name version
  ///  @instance
  ///  @memberof MapLibreMap
  ///  @var {string} version
  String get version => jsObject.version;

  /// Creates a new MapLibreMap from a [jsObject].
  MapLibreMap.fromJsObject(this.jsObject) : super.fromJsObject(jsObject);
}

class MapOptions extends JsObjectWrapper<MapOptionsJsImpl> {
  /// If `true`, the map's position (zoom, center latitude, center longitude, bearing, and pitch) will be synced with the hash fragment of the page's URL.
  /// For example, `http://path/to/my/page.html#2.59/39.26/53.07/-24.1/60`.
  /// An additional string may optionally be provided to indicate a parameter-styled hash,
  /// e.g. http://path/to/my/page.html#map=2.59/39.26/53.07/-24.1/60&foo=bar, where foo
  /// is a custom parameter and bar is an arbitrary hash distinct from the map hash.
  /// `bool` or `String`
  dynamic get hash => jsObject.hash;

  /// If `false`, no mouse, touch, or keyboard listeners will be attached to the map, so it will not respond to interaction.
  bool get interactive => jsObject.interactive;

  /// The HTML element in which MapLibre JS JS will render the map, or the element's string `id`. The specified element must have no children.
  /// `HTMLElement` or `String`
  dynamic get container => jsObject.container;

  /// The threshold, measured in degrees, that determines when the map's
  /// bearing will snap to north. For example, with a `bearingSnap` of 7, if the user rotates
  /// the map within 7 degrees of north, the map will automatically snap to exact north.
  num get bearingSnap => jsObject.bearingSnap;

  /// If `false`, the map's pitch (tilt) control with "drag to rotate" interaction will be disabled.
  bool get pitchWithRotate => jsObject.pitchWithRotate;

  ///  The max number of pixels a user can shift the mouse pointer during a click for it to be considered a valid click (as opposed to a mouse drag).
  num get clickTolerance => jsObject.clickTolerance;

  /// If `true`, an {@link AttributionControl} will be added to the map.
  bool get attributionControl => jsObject.attributionControl;

  /// String or strings to show in an {@link AttributionControl}. Only applicable if `options.attributionControl` is `true`.
  /// `String` or `List<String>`
  dynamic get customAttribution => jsObject.customAttribution;

  /// A string representing the position of the MapLibre wordmark on the map. Valid options are `top-left`,`top-right`, `bottom-left`, `bottom-right`.
  String get logoPosition => jsObject.logoPosition;

  /// If `true`, map creation will fail if the performance of MapLibre
  /// GL JS would be dramatically worse than expected (i.e. a software renderer would be used).
  bool get failIfMajorPerformanceCaveat =>
      jsObject.failIfMajorPerformanceCaveat;

  /// If `true`, the map's canvas can be exported to a PNG using `map.getCanvas().toDataURL()`. This is `false` by default as a performance optimization.
  bool get preserveDrawingBuffer => jsObject.preserveDrawingBuffer;

  /// If `true`, the gl context will be created with MSAA antialiasing, which can be useful for antialiasing custom layers. this is `false` by default as a performance optimization.
  bool get antialias => jsObject.antialias;

  /// If `false`, the map won't attempt to re-request tiles once they expire per their HTTP `cacheControl`/`expires` headers.
  bool get refreshExpiredTiles => jsObject.refreshExpiredTiles;

  /// If set, the map will be constrained to the given bounds.
  LngLatBounds get maxBounds => LngLatBounds.fromJsObject(jsObject.maxBounds);

  /// If `true`, the "scroll to zoom" interaction is enabled. An `Object` value is passed as options to {@link ScrollZoomHandler#enable}.
  bool get scrollZoom => jsObject.scrollZoom;

  /// The minimum zoom level of the map (0-24).
  num get minZoom => jsObject.minZoom;

  /// The maximum zoom level of the map (0-24).
  num get maxZoom => jsObject.maxZoom;

  /// The minimum pitch of the map (0-60).
  num get minPitch => jsObject.minPitch;

  /// The maximum pitch of the map (0-60).
  num get maxPitch => jsObject.maxPitch;

  ///  The map's MapLibre style. This must be an a JSON object conforming to
  ///  the schema described in the [MapLibre Style Specification](https://maplibre.org/maplibre-style-spec/), or a URL to
  ///  such JSON.
  dynamic get style => jsObject.style;

  /// If `true`, the "box zoom" interaction is enabled (see {@link BoxZoomHandler}).
  bool get boxZoom => jsObject.boxZoom;

  /// If `true`, the "drag to rotate" interaction is enabled (see {@link DragRotateHandler}).
  bool get dragRotate => jsObject.dragRotate;

  /// If `true`, the "drag to pan" interaction is enabled. An `Object` value is passed as options to {@link DragPanHandler#enable}.
  dynamic get dragPan => jsObject.dragPan;

  /// If `true`, keyboard shortcuts are enabled (see {@link KeyboardHandler}).
  bool get keyboard => jsObject.keyboard;

  /// If `true`, the "double click to zoom" interaction is enabled (see {@link DoubleClickZoomHandler}).
  bool get doubleClickZoom => jsObject.doubleClickZoom;

  /// If `true`, the "pinch to rotate and zoom" interaction is enabled. An `Object` value is passed as options to {@link TouchZoomRotateHandler#enable}.
  bool get touchZoomRotate => jsObject.touchZoomRotate;

  /// If `true`, the map will automatically resize when the browser window resizes.
  bool get trackResize => jsObject.trackResize;

  /// The inital geographical centerpoint of the map. If `center` is not specified in the constructor options, MapLibre JS JS will look for it in the map's style object. If it is not specified in the style, either, it will default to `[0, 0]` Note: MapLibre JS uses longitude, latitude coordinate order (as opposed to latitude, longitude) to match GeoJSON.
  LngLat get center => LngLat.fromJsObject(jsObject.center);

  /// The initial zoom level of the map. If `zoom` is not specified in the constructor options, MapLibre JS JS will look for it in the map's style object. If it is not specified in the style, either, it will default to `0`.
  num get zoom => jsObject.zoom;

  /// The initial bearing (rotation) of the map, measured in degrees counter-clockwise from north. If `bearing` is not specified in the constructor options, MapLibre JS JS will look for it in the map's style object. If it is not specified in the style, either, it will default to `0`.
  num get bearing => jsObject.bearing;

  /// The initial pitch (tilt) of the map, measured in degrees away from the plane of the screen (0-60). If `pitch` is not specified in the constructor options, MapLibre JS JS will look for it in the map's style object. If it is not specified in the style, either, it will default to `0`.
  num get pitch => jsObject.pitch;

  /// The initial bounds of the map. If `bounds` is specified, it overrides `center` and `zoom` constructor options.
  LngLatBounds get bounds => LngLatBounds.fromJsObject(jsObject.bounds);

  /// A [`fitBounds`](#map#fitbounds) options object to use _only_ when fitting the initial `bounds` provided above.
  dynamic get fitBoundsOptions => jsObject.fitBoundsOptions;

  /// If `true`, multiple copies of the world will be rendered side by side beyond -180 and 180 degrees longitude. If set to `false`:
  /// - When the map is zoomed out far enough that a single representation of the world does not fill the map's entire
  /// container, there will be blank space beyond 180 and -180 degrees longitude.
  /// - Features that cross 180 and -180 degrees longitude will be cut in two (with one portion on the right edge of the
  /// map and the other on the left edge of the map) at every zoom level.
  bool get renderWorldCopies => jsObject.renderWorldCopies;

  /// The maximum number of tiles stored in the tile cache for a given source. If omitted, the cache will be dynamically sized based on the current viewport.
  num get maxTileCacheSize => jsObject.maxTileCacheSize;

  /// Defines a CSS
  /// font-family for locally overriding generation of glyphs in the 'CJK Unified Ideographs', 'Hiragana', 'Katakana' and 'Hangul Syllables' ranges.
  /// In these ranges, font settings from the map's style will be ignored, except for font-weight keywords (light/regular/medium/bold).
  /// Set to `false`, to enable font settings from the map's style for these glyph ranges.
  /// The purpose of this option is to avoid bandwidth-intensive glyph server requests. (See [Use locally generated ideographs](https://maplibre.org/maplibre-gl-js/docs/examples/local-ideographs).)
  String get localIdeographFontFamily => jsObject.localIdeographFontFamily;

  /// A callback run before the MapLibreMap makes a request for an external URL. The callback can be used to modify the url, set headers, or set the credentials property for cross-origin requests.
  /// Expected to return an object with a `url` property and optionally `headers` and `credentials` properties.
  RequestTransformFunctionJsImpl get transformRequest =>
      jsObject.transformRequest; //TODO: Remove JsImpl

  /// If `true`, Resource Timing API information will be collected for requests made by GeoJSON and Vector Tile web workers (this information is normally inaccessible from the main Javascript thread). Information will be returned in a `resourceTiming` property of relevant `data` events.
  bool get collectResourceTiming => jsObject.collectResourceTiming;

  /// Controls the duration of the fade-in/fade-out animation for label collisions, in milliseconds. This setting affects all symbol layers. This setting does not affect the duration of runtime styling transitions or raster tile cross-fading.
  num get fadeDuration => jsObject.fadeDuration;

  /// If `true`, symbols from multiple sources can collide with each other during collision detection. If `false`, collision detection is run separately for the symbols in each source.
  bool get crossSourceCollisions => jsObject.crossSourceCollisions;

  /// If specified, map will use this token instead of the one defined in accessToken.
  String get accessToken => jsObject.accessToken;

  /// A patch to apply to the default localization table for UI strings, e.g. control tooltips. The `locale` object maps namespaced UI string IDs to translated strings in the target language; see `src/ui/default_locale.js` for an example with all supported string IDs. The object may specify all UI strings (thereby adding support for a new translation) or only a subset of strings (thereby patching the default translation table).
  dynamic get locale => jsObject.locale;

  factory MapOptions({
    dynamic hash,
    bool? interactive,
    dynamic container,
    num? bearingSnap,
    bool? pitchWithRotate,
    bool? clickTolerance,
    bool? attributionControl,
    dynamic customAttribution,
    String? logoPosition,
    bool? failIfMajorPerformanceCaveat,
    bool? preserveDrawingBuffer,
    bool? antialias,
    bool? refreshExpiredTiles,
    LngLatBounds? maxBounds,
    bool? scrollZoom,
    num? minZoom,
    num? maxZoom,
    num? minPitch,
    num? maxPitch,
    dynamic style,
    bool? boxZoom,
    bool? dragRotate,
    dynamic dragPan,
    bool? keyboard,
    bool? doubleClickZoom,
    bool? touchZoomRotate,
    bool? trackResize,
    LngLat? center,
    num? zoom,
    num? bearing,
    num? pitch,
    LngLatBounds? bounds,
    dynamic fitBoundsOptions,
    bool? renderWorldCopies,
    num? maxTileCacheSize,
    String? localIdeographFontFamily,
    RequestTransformFunctionJsImpl? transformRequest, //TODO: Remove JsImpl
    bool? collectResourceTiming,
    num? fadeDuration,
    bool? crossSourceCollisions,
    String? accessToken,
    dynamic locale,
  }) =>
      MapOptions.fromJsObject(MapOptionsJsImpl(
        //hash: hash,
        interactive: interactive ?? true,
        container: container,
        bearingSnap: bearingSnap,
        pitchWithRotate: pitchWithRotate ?? true,
        clickTolerance: clickTolerance ?? true,
        attributionControl: attributionControl ?? true,
        customAttribution: customAttribution,
        logoPosition: logoPosition ?? 'bottom-left',
        failIfMajorPerformanceCaveat: failIfMajorPerformanceCaveat,
        preserveDrawingBuffer: preserveDrawingBuffer,
        antialias: antialias,
        refreshExpiredTiles: refreshExpiredTiles,
        maxBounds: maxBounds?.jsObject,
        scrollZoom: scrollZoom ?? true,
        minZoom: minZoom,
        maxZoom: maxZoom,
        minPitch: minPitch,
        maxPitch: maxPitch,
        style: style,
        boxZoom: boxZoom,
        dragRotate: dragRotate,
        dragPan: dragPan ?? true,
        keyboard: keyboard ?? true,
        doubleClickZoom: doubleClickZoom ?? true,
        touchZoomRotate: touchZoomRotate ?? true,
        trackResize: trackResize ?? true,
        center: center?.jsObject,
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
        bounds: bounds?.jsObject,
        fitBoundsOptions: fitBoundsOptions,
        renderWorldCopies: renderWorldCopies,
        maxTileCacheSize: maxTileCacheSize,
        localIdeographFontFamily: localIdeographFontFamily,
        transformRequest: transformRequest,
        collectResourceTiming: collectResourceTiming,
        fadeDuration: fadeDuration,
        crossSourceCollisions: crossSourceCollisions,
        accessToken: accessToken,
        locale: locale,
      ));

  /// Creates a new MapOptions from a [jsObject].
  MapOptions.fromJsObject(MapOptionsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

class RequestParameters extends JsObjectWrapper<RequestParametersJsImpl> {
  String? get url => jsObject.url;

  String? get credentials => jsObject.credentials;

  dynamic get headers => jsObject.headers;

  String? get method => jsObject.method;

  bool? get collectResourceTiming => jsObject.collectResourceTiming;

  factory RequestParameters({
    String? url,
    String? credentials,
    dynamic headers,
    String? method,
    bool? collectResourceTiming,
  }) =>
      RequestParameters.fromJsObject(RequestParametersJsImpl(
        url: url,
        credentials: credentials,
        headers: headers,
        method: method,
        collectResourceTiming: collectResourceTiming,
      ));

  /// Creates a new RequestParameters from a [jsObject].
  RequestParameters.fromJsObject(RequestParametersJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

///  Interface for interactive controls added to the map. This is a
///  specification for implementers to model: it is not
///  an exported method or class.
///
///  Controls must implement `onAdd` and `onRemove`, and must own an
///  element, which is often a `div` element. To use MapLibre JS JS's
///  default control styling, add the `maplibregl-ctrl` class to your control's
///  node.
///
/// ```dart
/// class HelloWorldControl implements IControl {
///   DivElement _divElement;
///   @override
///   String getDefaultPosition() {
///     return 'bottom-left';
///   }
///
///   @override
///   HtmlElement onAdd(MapLibreMap map) {
///     _divElement = DivElement();
///     _divElement.text = 'Hello World';
///     return _divElement;
///   }
///
///   @override
///   onRemove(MapLibreMap map) {
///     _divElement.remove();
///   }
/// }
/// ```
class IControl extends JsObjectWrapper<IControlJsImpl> {
  ///  Register a control on the map and give it a chance to register event listeners
  ///  and resources. This method is called by {@link MapLibreMap#addControl}
  ///  internally.
  HtmlElement onAdd(MapLibreMap map) => jsObject.onAdd(map.jsObject);

  ///  Unregister a control on the map and give it a chance to detach event listeners
  ///  and resources. This method is called by {@link MapLibreMap#removeControl}
  ///  internally.
  onRemove(MapLibreMap map) => jsObject.onRemove(map.jsObject);

  ///  Optionally provide a default position for this control. If this method
  ///  is implemented and {@link MapLibreMap#addControl} is called without the `position`
  ///  parameter, the value returned by getDefaultPosition will be used as the
  ///  control's position.
  String getDefaultPosition() => jsObject.getDefaultPosition();

  /// Creates a new IControl from a [jsObject].
  IControl.fromJsObject(IControlJsImpl jsObject) : super.fromJsObject(jsObject);
}
