library maplibre.ui.events;

import 'dart:html';

import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/geo/point.dart';

class MapMouseEvent extends JsObjectWrapper<MapMouseEventJsImpl> {
  /// The event type.
  String get type => jsObject.type;

  /// The `MapLibreMap` object that fired the event.
  MapLibreMap get target => MapLibreMap.fromJsObject(jsObject.target);

  /// The DOM event which caused the map event.
  MouseEvent get originalEvent => jsObject.originalEvent;

  /// The pixel coordinates of the mouse cursor, relative to the map and measured from the top left corner.
  Point get point => Point.fromJsObject(jsObject.point);

  /// The geographic location on the map of the mouse cursor.
  LngLat get lngLat => LngLat.fromJsObject(jsObject.lngLat);

  ///  Prevents subsequent default processing of the event by the map.
  ///
  ///  Calling this method will prevent the following default map behaviors:
  ///
  ///  *  On `mousedown` events, the behavior of {@link DragPanHandler}
  ///  *  On `mousedown` events, the behavior of {@link DragRotateHandler}
  ///  *  On `mousedown` events, the behavior of {@link BoxZoomHandler}
  ///  *  On `dblclick` events, the behavior of {@link DoubleClickZoomHandler}
  preventDefault() => jsObject.preventDefault();

  /// `true` if `preventDefault` has been called.
  bool get defaultPrevented => jsObject.defaultPrevented;

  /// Creates a new MapMouseEvent from a [jsObject].
  MapMouseEvent.fromJsObject(MapMouseEventJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

class MapTouchEvent extends JsObjectWrapper<MapTouchEventJsImpl> {
  /// The event type.
  String get type => jsObject.type;

  /// The `MapLibreMap` object that fired the event.
  MapLibreMap get target => MapLibreMap.fromJsObject(jsObject.target);

  /// The DOM event which caused the map event.
  TouchEvent get originalEvent => jsObject.originalEvent;

  /// The geographic location on the map of the center of the touch event points.
  LngLat get lngLat => LngLat.fromJsObject(jsObject.lngLat);

  /// The pixel coordinates of the center of the touch event points, relative to the map and measured from the top left
  /// corner.
  Point get point => Point.fromJsObject(jsObject.point);

  ///  The array of pixel coordinates corresponding to a
  ///  [touch event's `touches`](https://developer.mozilla.org/en-US/docs/Web/API/TouchEvent/touches) property.
  List<Point> get points =>
      jsObject.points.map((f) => Point.fromJsObject(f)).toList();

  ///  The geographical locations on the map corresponding to a
  ///  [touch event's `touches`](https://developer.mozilla.org/en-US/docs/Web/API/TouchEvent/touches) property.
  List<LngLat> get lngLats =>
      jsObject.lngLats.map((dynamic f) => LngLat.fromJsObject(f)).toList();

  ///  Prevents subsequent default processing of the event by the map.
  ///
  ///  Calling this method will prevent the following default map behaviors:
  ///
  ///  *  On `touchstart` events, the behavior of {@link DragPanHandler}
  ///  *  On `touchstart` events, the behavior of {@link TouchZoomRotateHandler}
  preventDefault() => jsObject.preventDefault();

  ///  `true` if `preventDefault` has been called.
  bool get defaultPrevented => jsObject.defaultPrevented;

  /// Creates a new MapTouchEvent from a [jsObject].
  MapTouchEvent.fromJsObject(MapTouchEventJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
