library maplibre.geo.lng_lat_bounds;

import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';

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
class LngLatBounds extends JsObjectWrapper<LngLatBoundsJsImpl> {
  factory LngLatBounds(
    LngLat sw,
    LngLat ne,
  ) =>
      LngLatBounds.fromJsObject(LngLatBoundsJsImpl(
        sw.jsObject,
        ne.jsObject,
      ));

  ///  Set the northeast corner of the bounding box
  ///
  ///  @param {LngLatLike} ne
  ///  @returns {LngLatBounds} `this`
  LngLatBounds setNorthEast(LngLat ne) =>
      LngLatBounds.fromJsObject(jsObject.setNorthEast(ne.jsObject));

  ///  Set the southwest corner of the bounding box
  ///
  ///  @param {LngLatLike} sw
  ///  @returns {LngLatBounds} `this`
  LngLatBounds setSouthWest(LngLat sw) =>
      LngLatBounds.fromJsObject(jsObject.setSouthWest(sw.jsObject));

  ///  Extend the bounds to include a given LngLat or LngLatBounds.
  ///
  ///  @param {LngLat|LngLatBounds} obj object to extend to
  ///  @returns {LngLatBounds} `this`
  LngLatBounds extend(dynamic obj) =>
      LngLatBounds.fromJsObject(jsObject.extend(obj.jsObject));

  ///  Returns the geographical coordinate equidistant from the bounding box's corners.
  ///
  ///  @returns {LngLat} The bounding box's center.
  ///  @example
  ///  var llb = new maplibregl.LngLatBounds([-73.9876, 40.7661], [-73.9397, 40.8002]);
  ///  llb.getCenter(); // = LngLat {lng: -73.96365, lat: 40.78315}
  LngLat getCenter() => LngLat.fromJsObject(jsObject.getCenter());

  ///  Returns the southwest corner of the bounding box.
  ///
  ///  @returns {LngLat} The southwest corner of the bounding box.
  LngLat getSouthWest() => LngLat.fromJsObject(jsObject.getSouthWest());

  ///  Returns the northeast corner of the bounding box.
  ///
  ///  @returns {LngLat} The northeast corner of the bounding box.
  LngLat getNorthEast() => LngLat.fromJsObject(jsObject.getNorthEast());

  ///  Returns the northwest corner of the bounding box.
  ///
  ///  @returns {LngLat} The northwest corner of the bounding box.
  LngLat getNorthWest() => LngLat.fromJsObject(jsObject.getNorthWest());

  ///  Returns the southeast corner of the bounding box.
  ///
  ///  @returns {LngLat} The southeast corner of the bounding box.
  LngLat getSouthEast() => LngLat.fromJsObject(jsObject.getSouthEast());

  ///  Returns the west edge of the bounding box.
  ///
  ///  @returns {number} The west edge of the bounding box.
  num getWest() => jsObject.getWest();

  ///  Returns the south edge of the bounding box.
  ///
  ///  @returns {number} The south edge of the bounding box.
  num getSouth() => jsObject.getSouth();

  ///  Returns the east edge of the bounding box.
  ///
  ///  @returns {number} The east edge of the bounding box.
  num getEast() => jsObject.getEast();

  ///  Returns the north edge of the bounding box.
  ///
  ///  @returns {number} The north edge of the bounding box.
  num getNorth() => jsObject.getNorth();

  ///  Returns the bounding box represented as an array.
  ///
  ///  @returns {Array<Array<number>>} The bounding box represented as an array, consisting of the
  ///    southwest and northeast coordinates of the bounding represented as arrays of numbers.
  ///  @example
  ///  var llb = new maplibregl.LngLatBounds([-73.9876, 40.7661], [-73.9397, 40.8002]);
  ///  llb.toArray(); // = [[-73.9876, 40.7661], [-73.9397, 40.8002]]
  List<List<num>> toArray() => jsObject.toArray();

  ///  Return the bounding box represented as a string.
  ///
  ///  @returns {string} The bounding box represents as a string of the format
  ///    `'LngLatBounds(LngLat(lng, lat), LngLat(lng, lat))'`.
  ///  @example
  ///  var llb = new maplibregl.LngLatBounds([-73.9876, 40.7661], [-73.9397, 40.8002]);
  ///  llb.toString(); // = "LngLatBounds(LngLat(-73.9876, 40.7661), LngLat(-73.9397, 40.8002))"
  String toString() => jsObject.toString();

  ///  Check if the bounding box is an empty/`null`-type box.
  ///
  ///  @returns {boolean} True if bounds have been defined, otherwise false.
  bool isEmpty() => jsObject.isEmpty();

  ///  Check if the point is within the bounding box.
  ///
  ///  @param {LngLatLike} lnglat geographic point to check against.
  ///  @returns {boolean} True if the point is within the bounding box.
  bool contains(LngLat lnglat) => jsObject.contains(lnglat.jsObject);

  ///  Converts an array to a `LngLatBounds` object.
  ///
  ///  If a `LngLatBounds` object is passed in, the function returns it unchanged.
  ///
  ///  Internally, the function calls `LngLat#convert` to convert arrays to `LngLat` values.
  ///
  ///  @param {LngLatBoundsLike} input An array of two coordinates to convert, or a `LngLatBounds` object to return.
  ///  @returns {LngLatBounds} A new `LngLatBounds` object, if a conversion occurred, or the original `LngLatBounds` object.
  ///  @example
  ///  var arr = [[-73.9876, 40.7661], [-73.9397, 40.8002]];
  ///  var llb = maplibregl.LngLatBounds.convert(arr);
  ///  llb;   // = LngLatBounds {_sw: LngLat {lng: -73.9876, lat: 40.7661}, _ne: LngLat {lng: -73.9397, lat: 40.8002}}
  static LngLatBounds convert(dynamic input) =>
      LngLatBounds.fromJsObject(LngLatBoundsJsImpl.convert(input));

  /// Creates a new LngLatBounds from a [jsObject].
  LngLatBounds.fromJsObject(LngLatBoundsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
