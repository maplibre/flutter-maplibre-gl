@JS('maplibregl')
library mapboxgl.interop.ui.camera;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_bounds_interop.dart';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_interop.dart';
import 'package:maplibre_gl_web/src/interop/geo/point_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

///  Options common to {@link MapboxMap#jumpTo}, {@link MapboxMap#easeTo}, and {@link MapboxMap#flyTo}, controlling the desired location,
///  zoom, bearing, and pitch of the camera. All properties are optional, and when a property is omitted, the current
///  camera value for that property will remain unchanged.
///
///  @typedef {Object} CameraOptions
///  @property {LngLatLike} center The desired center.
///  @property {number} zoom The desired zoom level.
///  @property {number} bearing The desired bearing, in degrees. The bearing is the compass direction that
///  is "up"; for example, a bearing of 90° orients the map so that east is up.
///  @property {number} pitch The desired pitch, in degrees.
///  @property {LngLatLike} around If `zoom` is specified, `around` determines the point around which the zoom is centered.
@JS()
@anonymous
class CameraOptionsJsImpl {
  external LngLatJsImpl get center;

  external num get zoom;

  external num get bearing;

  external num get pitch;

  external LngLatJsImpl get around;

  external factory CameraOptionsJsImpl({
    LngLatJsImpl? center,
    num? zoom,
    num? bearing,
    num? pitch,
    LngLatJsImpl? around,
  });
}

///  Options common to map movement methods that involve animation, such as {@link MapboxMap#panBy} and
///  {@link MapboxMap#easeTo}, controlling the duration and easing function of the animation. All properties
///  are optional.
///
///  @typedef {Object} AnimationOptions
///  @property {number} duration The animation's duration, measured in milliseconds.
///  @property {Function} easing A function taking a time in the range 0..1 and returning a number where 0 is
///    the initial state and 1 is the final state.
///  @property {PointLike} offset of the target center relative to real map container center at the end of animation.
///  @property {boolean} animate If `false`, no animation will occur.
///  @property {boolean} essential If `true`, then the animation is considered essential and will not be affected by
///    [`prefers-reduced-motion`](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion).
@JS()
@anonymous
class AnimationOptionsJsImpl {
  external num get duration;

  external num Function(num time) get easing;

  external PointJsImpl get offset;

  external bool get animate;

  external bool get essential;

  external factory AnimationOptionsJsImpl({
    num? duration,
    num Function(num time)? easing,
    PointJsImpl? offset,
    bool? animate,
    bool? essential,
  });
}

///  Options for setting padding on a call to {@link MapboxMap#fitBounds}. All properties of this object must be
///  non-negative integers.
///
///  @typedef {Object} PaddingOptions
///  @property {number} top Padding in pixels from the top of the map canvas.
///  @property {number} bottom Padding in pixels from the bottom of the map canvas.
///  @property {number} left Padding in pixels from the left of the map canvas.
///  @property {number} right Padding in pixels from the right of the map canvas.
@JS()
@anonymous
class PaddingOptionsJsImpl {
  external num get top;

  external num get bottom;

  external num get left;

  external num get right;

  external factory PaddingOptionsJsImpl({
    num? top,
    num? bottom,
    num? left,
    num? right,
  });
}

@JS('Camera')
abstract class CameraJsImpl extends EventedJsImpl {
  ///  Returns the map's geographical centerpoint.
  ///
  ///  @memberof MapboxMap#
  ///  @returns The map's geographical centerpoint.
  external LngLatJsImpl getCenter();

  ///  Sets the map's geographical centerpoint. Equivalent to `jumpTo({center: center})`.
  ///
  ///  @memberof MapboxMap#
  ///  @param center The centerpoint to set.
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  ///  @example
  ///  map.setCenter([-74, 38]);
  external MapboxMapJsImpl setCenter(LngLatJsImpl center, [dynamic eventData]);

  ///  Pans the map by the specified offset.
  ///
  ///  @memberof MapboxMap#
  ///  @param offset `x` and `y` coordinates by which to pan the map.
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  ///  @see [Navigate the map with game-like controls](https://www.mapbox.com/mapbox-gl-js/example/game-controls/)
  external MapboxMapJsImpl panBy(PointJsImpl offset,
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Pans the map to the specified location, with an animated transition.
  ///
  ///  @memberof MapboxMap#
  ///  @param lnglat The location to pan the map to.
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl panTo(LngLatJsImpl lnglat,
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Returns the map's current zoom level.
  ///
  ///  @memberof MapboxMap#
  ///  @returns The map's current zoom level.
  external num getZoom();

  ///  Sets the map's zoom level. Equivalent to `jumpTo({zoom: zoom})`.
  ///
  ///  @memberof MapboxMap#
  ///  @param zoom The zoom level to set (0-20).
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires zoomstart
  ///  @fires move
  ///  @fires zoom
  ///  @fires moveend
  ///  @fires zoomend
  ///  @returns {MapboxMap} `this`
  ///  @example
  ///  // zoom the map to 5
  ///  map.setZoom(5);
  external MapboxMapJsImpl setZoom(num zoom, [dynamic eventData]);

  ///  Zooms the map to the specified zoom level, with an animated transition.
  ///
  ///  @memberof MapboxMap#
  ///  @param zoom The zoom level to transition to.
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires zoomstart
  ///  @fires move
  ///  @fires zoom
  ///  @fires moveend
  ///  @fires zoomend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl zoomTo(num zoom,
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Increases the map's zoom level by 1.
  ///
  ///  @memberof MapboxMap#
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires zoomstart
  ///  @fires move
  ///  @fires zoom
  ///  @fires moveend
  ///  @fires zoomend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl zoomIn(
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Decreases the map's zoom level by 1.
  ///
  ///  @memberof MapboxMap#
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires zoomstart
  ///  @fires move
  ///  @fires zoom
  ///  @fires moveend
  ///  @fires zoomend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl zoomOut(
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Returns the map's current bearing. The bearing is the compass direction that is \"up\"; for example, a bearing
  ///  of 90° orients the map so that east is up.
  ///
  ///  @memberof MapboxMap#
  ///  @returns The map's current bearing.
  ///  @see [Navigate the map with game-like controls](https://www.mapbox.com/mapbox-gl-js/example/game-controls/)
  external num getBearing();

  ///  Sets the map's bearing (rotation). The bearing is the compass direction that is \"up\"; for example, a bearing
  ///  of 90° orients the map so that east is up.
  ///
  ///  Equivalent to `jumpTo({bearing: bearing})`.
  ///
  ///  @memberof MapboxMap#
  ///  @param bearing The desired bearing.
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  ///  @example
  ///  // rotate the map to 90 degrees
  ///  map.setBearing(90);
  external MapboxMapJsImpl setBearing(num bearing, [dynamic eventData]);

  ///  Rotates the map to the specified bearing, with an animated transition. The bearing is the compass direction
  ///  that is \"up\"; for example, a bearing of 90° orients the map so that east is up.
  ///
  ///  @memberof MapboxMap#
  ///  @param bearing The desired bearing.
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl rotateTo(num bearing,
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Rotates the map so that north is up (0° bearing), with an animated transition.
  ///
  ///  @memberof MapboxMap#
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl resetNorth(
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Rotates and pitches the map so that north is up (0° bearing) and pitch is 0°, with an animated transition.
  ///
  ///  @memberof MapboxMap#
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl resetNorthPitch(
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Snaps the map so that north is up (0° bearing), if the current bearing is close enough to it (i.e. within the
  ///  `bearingSnap` threshold).
  ///
  ///  @memberof MapboxMap#
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl snapToNorth(
      [AnimationOptionsJsImpl? options, dynamic eventData]);

  ///  Returns the map's current pitch (tilt).
  ///
  ///  @memberof MapboxMap#
  ///  @returns The map's current pitch, measured in degrees away from the plane of the screen.
  external num getPitch();

  ///  Sets the map's pitch (tilt). Equivalent to `jumpTo({pitch: pitch})`.
  ///
  ///  @memberof MapboxMap#
  ///  @param pitch The pitch to set, measured in degrees away from the plane of the screen (0-60).
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires pitchstart
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl setPitch(num pitch, [dynamic eventData]);

  ///  @memberof MapboxMap#
  ///  @param {LatLngBoundsLike} bounds Calculate the center for these bounds in the viewport and use
  ///       the highest zoom level up to and including `MapboxMap#getMaxZoom()` that fits
  ///       in the viewport. LatLngBounds represent a box that is always axis-aligned with bearing 0.
  ///  @param options
  ///  @param {number | PaddingOptions} `options.padding` The amount of padding in pixels to add to the given bounds.
  ///  @param {PointLike} `options.offset=[0, 0]` The center of the given bounds relative to the map's center, measured in pixels.
  ///  @param {number} `options.maxZoom` The maximum zoom level to allow when the camera would transition to the specified bounds.
  ///  @returns {CameraOptions | void} If map is able to fit to provided bounds, returns `CameraOptions` with
  ///       `center`, `zoom`, and `bearing`. If map is unable to fit, method will warn and return undefined.
  ///  @example
  ///  var bbox = [[-79, 43], [-73, 45]];
  ///  var newCameraTransform = map.cameraForBounds(bbox, {
  ///    padding: {top: 10, bottom:25, left: 15, right: 5}
  ///  });
  external CameraOptionsJsImpl cameraForBounds(LngLatBoundsJsImpl bounds,
      [CameraOptionsJsImpl? options]);

  ///  Pans and zooms the map to contain its visible area within the specified geographical bounds.
  ///  This function will also reset the map's bearing to 0 if bearing is nonzero.
  ///
  ///  @memberof MapboxMap#
  ///  @param bounds Center these bounds in the viewport and use the highest
  ///       zoom level up to and including `MapboxMap#getMaxZoom()` that fits them in the viewport.
  ///  @param {Object} [options] Options supports all properties from {@link AnimationOptions} and {@link CameraOptions} in addition to the fields below.
  ///  @param {number | PaddingOptions} `options.padding` The amount of padding in pixels to add to the given bounds.
  ///  @param {boolean} `options.linear=false` If `true`, the map transitions using
  ///      {@link MapboxMap#easeTo}. If `false`, the map transitions using {@link MapboxMap#flyTo}. See
  ///      those functions and {@link AnimationOptions} for information about options available.
  ///  @param {Function} `options.easing` An easing function for the animated transition. See {@link AnimationOptions}.
  ///  @param {PointLike} `options.offset=[0, 0]` The center of the given bounds relative to the map's center, measured in pixels.
  ///  @param {number} `options.maxZoom` The maximum zoom level to allow when the map view transitions to the specified bounds.
  ///  @param {Object} [eventData] Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  ///  @example
  ///  var bbox = [[-79, 43], [-73, 45]];
  ///  map.fitBounds(bbox, {
  ///    padding: {top: 10, bottom:25, left: 15, right: 5}
  ///  });
  ///  @see [Fit a map to a bounding box](https://www.mapbox.com/mapbox-gl-js/example/fitbounds/)
  external MapboxMapJsImpl fitBounds(LngLatBoundsJsImpl bounds,
      [dynamic options, dynamic eventData]);

  ///  Pans, rotates and zooms the map to to fit the box made by points p0 and p1
  ///  once the map is rotated to the specified bearing. To zoom without rotating,
  ///  pass in the current map bearing.
  ///
  ///  @memberof MapboxMap#
  ///  @param p0 First point on screen, in pixel coordinates
  ///  @param p1 Second point on screen, in pixel coordinates
  ///  @param bearing Desired map bearing at end of animation, in degrees
  ///  @param options
  ///  @param {number | PaddingOptions} `options.padding` The amount of padding in pixels to add to the given bounds.
  ///  @param {boolean} `options.linear=false` If `true`, the map transitions using
  ///      {@link MapboxMap#easeTo}. If `false`, the map transitions using {@link MapboxMap#flyTo}. See
  ///      those functions and {@link AnimationOptions} for information about options available.
  ///  @param {Function} `options.easing` An easing function for the animated transition. See {@link AnimationOptions}.
  ///  @param {PointLike} `options.offset=[0, 0]` The center of the given bounds relative to the map's center, measured in pixels.
  ///  @param {number} `options.maxZoom` The maximum zoom level to allow when the map view transitions to the specified bounds.
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires moveend
  ///  @returns {MapboxMap} `this`
  ///  @example
  ///  var p0 = [220, 400];
  ///  var p1 = [500, 900];
  ///  map.fitScreenCoordinates(p0, p1, map.getBearing(), {
  ///    padding: {top: 10, bottom:25, left: 15, right: 5}
  ///  });
  ///  @see [Used by BoxZoomHandler](https://www.mapbox.com/mapbox-gl-js/api/#boxzoomhandler)
  external MapboxMapJsImpl fitScreenCoordinates(
      PointJsImpl p0, PointJsImpl p1, num bearing,
      [dynamic options, dynamic eventData]);

  ///  Changes any combination of center, zoom, bearing, and pitch, without
  ///  an animated transition. The map will retain its current values for any
  ///  details not specified in [options].
  ///
  ///  @memberof MapboxMap#
  ///  @param options
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires zoomstart
  ///  @fires pitchstart
  ///  @fires rotate
  ///  @fires move
  ///  @fires zoom
  ///  @fires pitch
  ///  @fires moveend
  ///  @fires zoomend
  ///  @fires pitchend
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl jumpTo(CameraOptionsJsImpl options,
      [dynamic eventData]);

  ///  Changes any combination of center, zoom, bearing, and pitch, with an animated transition
  ///  between old and new values. The map will retain its current values for any
  ///  details not specified in [options].
  ///
  ///  Note: The transition will happen instantly if the user has enabled
  ///  the `reduced motion` accesibility feature enabled in their operating system.
  ///
  ///  @memberof MapboxMap#
  ///  @param options Options describing the destination and animation of the transition.
  ///             Accepts {@link CameraOptions} and {@link AnimationOptions}.
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires zoomstart
  ///  @fires pitchstart
  ///  @fires rotate
  ///  @fires move
  ///  @fires zoom
  ///  @fires pitch
  ///  @fires moveend
  ///  @fires zoomend
  ///  @fires pitchend
  ///  @returns {MapboxMap} `this`
  ///  @see [Navigate the map with game-like controls](https://www.mapbox.com/mapbox-gl-js/example/game-controls/)
  external MapboxMapJsImpl easeTo(dynamic options, [dynamic eventData]);

  ///  Changes any combination of center, zoom, bearing, and pitch, animating the transition along a curve that
  ///  evokes flight. The animation seamlessly incorporates zooming and panning to help
  ///  the user maintain her bearings even after traversing a great distance.
  ///
  ///  Note: The animation will be skipped, and this will behave equivalently to `jumpTo`
  ///  if the user has the `reduced motion` accesibility feature enabled in their operating system.
  ///
  ///  @memberof MapboxMap#
  ///  @param {Object} options Options describing the destination and animation of the transition.
  ///      Accepts {@link CameraOptions}, {@link AnimationOptions},
  ///      and the following additional options.
  ///  @param {number} [options.curve=1.42] The zooming "curve" that will occur along the
  ///      flight path. A high value maximizes zooming for an exaggerated animation, while a low
  ///      value minimizes zooming for an effect closer to {@link MapboxMap#easeTo}. 1.42 is the average
  ///      value selected by participants in the user study discussed in
  ///      [van Wijk (2003)](https://www.win.tue.nl/~vanwijk/zoompan.pdf). A value of
  ///      `Math.pow(6, 0.25)` would be equivalent to the root mean squared average velocity. A
  ///      value of 1 would produce a circular motion.
  ///  @param {number} `options.minZoom` The zero-based zoom level at the peak of the flight path. If
  ///      `options.curve` is specified, this option is ignored.
  ///  @param {number} `options.speed=1.2` The average speed of the animation defined in relation to
  ///      `options.curve`. A speed of 1.2 means that the map appears to move along the flight path
  ///      by 1.2 times `options.curve` screenfuls every second. A _screenful_ is the map's visible span.
  ///      It does not correspond to a fixed physical distance, but varies by zoom level.
  ///  @param {number} `options.screenSpeed` The average speed of the animation measured in screenfuls
  ///      per second, assuming a linear timing curve. If `options.speed` is specified, this option is ignored.
  ///  @param {number} `options.maxDuration` The animation's maximum duration, measured in milliseconds.
  ///      If duration exceeds maximum duration, it resets to 0.
  ///  @param eventData Additional properties to be added to event objects of events triggered by this method.
  ///  @fires movestart
  ///  @fires zoomstart
  ///  @fires pitchstart
  ///  @fires move
  ///  @fires zoom
  ///  @fires rotate
  ///  @fires pitch
  ///  @fires moveend
  ///  @fires zoomend
  ///  @fires pitchend
  ///  @returns {MapboxMap} `this`
  ///  @example
  ///  // fly with default options to null island
  ///  map.flyTo({center: [0, 0], zoom: 9});
  ///  // using flyTo options
  ///  map.flyTo({
  ///    center: [0, 0],
  ///    zoom: 9,
  ///    speed: 0.2,
  ///    curve: 1,
  ///    easing(t) {
  ///      return t;
  ///    }
  ///  });
  ///  @see [Fly to a location](https://www.mapbox.com/mapbox-gl-js/example/flyto/)
  ///  @see [Slowly fly to a location](https://www.mapbox.com/mapbox-gl-js/example/flyto-options/)
  ///  @see [Fly to a location based on scroll position](https://www.mapbox.com/mapbox-gl-js/example/scroll-fly-to/)
  external MapboxMapJsImpl flyTo(dynamic options, [dynamic eventData]);

  external bool isEasing();

  ///  Stops any animated transition underway.
  ///
  ///  @memberof MapboxMap#
  ///  @returns {MapboxMap} `this`
  external MapboxMapJsImpl stop();
}
