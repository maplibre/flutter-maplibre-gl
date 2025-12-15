@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_interop.dart';

///  A `LngLatBounds` object represents a geographical bounding box,
///  defined by its southwest and northeast points in longitude and latitude.
///
///  If no arguments are provided to the constructor, a `null` bounding box is created.
///
///  Note that any MapLibre method that accepts a `LngLatBounds` object as an argument or option
///  can also accept an `Array` of two {@link LngLatLike} constructs and will perform an implicit conversion.
///  This flexible type is documented as {@link LngLatBoundsLike}.
///
///  @param {LngLatLike} [sw] The southwest corner of the bounding box.
///  @param {LngLatLike} [ne] The northeast corner of the bounding box.
///  @example
///  var sw = new maplibregl.LngLat(-73.9876, 40.7661);
///  var ne = new maplibregl.LngLat(-73.9397, 40.8002);
///  var llb = new maplibregl.LngLatBounds(sw, ne);
@JS('LngLatBounds')
@staticInterop
class LngLatBoundsJsImpl {
  external factory LngLatBoundsJsImpl(
    LngLatJsImpl sw,
    LngLatJsImpl ne,
  );
}

extension LngLatBoundsJsImplExtension on LngLatBoundsJsImpl {
  external LngLatJsImpl get sw;
  external LngLatJsImpl get ne;

  ///  Set the northeast corner of the bounding box
  ///
  ///  @param {LngLatLike} ne
  ///  @returns {LngLatBounds} `this`
  external LngLatBoundsJsImpl setNorthEast(LngLatJsImpl ne);

  ///  Set the southwest corner of the bounding box
  ///
  ///  @param {LngLatLike} sw
  ///  @returns {LngLatBounds} `this`
  external LngLatBoundsJsImpl setSouthWest(LngLatJsImpl sw);

  ///  Extend the bounds to include a given LngLat or LngLatBounds.
  ///
  ///  @param {LngLat|LngLatBounds} obj object to extend to
  ///  @returns {LngLatBounds} `this`
  external LngLatBoundsJsImpl extend(JSAny obj);

  ///  Returns the geographical coordinate equidistant from the bounding box's corners.
  ///
  ///  @returns {LngLat} The bounding box's center.
  ///  @example
  ///  var llb = new maplibregl.LngLatBounds([-73.9876, 40.7661], [-73.9397, 40.8002]);
  ///  llb.getCenter(); // = LngLat {lng: -73.96365, lat: 40.78315}
  external LngLatJsImpl getCenter();

  ///  Returns the southwest corner of the bounding box.
  ///
  ///  @returns {LngLat} The southwest corner of the bounding box.
  external LngLatJsImpl getSouthWest();

  ///  Returns the northeast corner of the bounding box.
  ///
  ///  @returns {LngLat} The northeast corner of the bounding box.
  external LngLatJsImpl getNorthEast();

  ///  Returns the northwest corner of the bounding box.
  ///
  ///  @returns {LngLat} The northwest corner of the bounding box.
  external LngLatJsImpl getNorthWest();

  ///  Returns the southeast corner of the bounding box.
  ///
  ///  @returns {LngLat} The southeast corner of the bounding box.
  external LngLatJsImpl getSouthEast();

  ///  Returns the west edge of the bounding box.
  ///
  ///  @returns {number} The west edge of the bounding box.
  external num getWest();

  ///  Returns the south edge of the bounding box.
  ///
  ///  @returns {number} The south edge of the bounding box.
  external num getSouth();

  ///  Returns the east edge of the bounding box.
  ///
  ///  @returns {number} The east edge of the bounding box.
  external num getEast();

  ///  Returns the north edge of the bounding box.
  ///
  ///  @returns {number} The north edge of the bounding box.
  external num getNorth();

  ///  Returns the bounding box represented as an array.
  ///
  ///  @returns `{Array<Array<number>>}` The bounding box represented as an array, consisting of the
  ///    southwest and northeast coordinates of the bounding represented as arrays of numbers.
  ///  @example
  ///  var llb = new maplibregl.LngLatBounds([-73.9876, 40.7661], [-73.9397, 40.8002]);
  ///  llb.toArray(); // = [[-73.9876, 40.7661], [-73.9397, 40.8002]]
  external JSArray<JSArray<JSNumber>> toArray();

  ///  Check if the bounding box is an empty/`null`-type box.
  ///
  ///  @returns {boolean} True if bounds have been defined, otherwise false.
  external bool isEmpty();

  ///  Check if the point is within the bounding box.
  ///
  ///  @param {LngLatLike} lnglat geographic point to check against.
  ///  @returns {boolean} True if the point is within the bounding box.
  external bool contains(LngLatJsImpl lnglat);
}

///  Converts an array to a `LngLatBounds` object.
///
///  If a `LngLatBounds` object is passed in, the function returns it unchanged.
///
///  Internally, the function calls `LngLat#convert` to convert arrays to `LngLat` values.
///
///  @param {LngLatBoundsLike} input An array of two coordinates to convert, or a `LngLatBounds` object to return.
///  @returns {LngLatBounds} A new `LngLatBounds` object, if a conversion occurred, or the original `LngLatBounds` object.
@JS('LngLatBounds.convert')
external LngLatBoundsJsImpl lngLatBoundsConvert(JSAny input);
