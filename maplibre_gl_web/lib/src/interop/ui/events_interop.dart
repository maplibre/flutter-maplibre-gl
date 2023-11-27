@JS('maplibregl')
library maplibre.interop.ui.events;

import 'dart:html';
import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_interop.dart';
import 'package:maplibre_gl_web/src/interop/geo/point_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

@JS()
@anonymous
abstract class MapMouseEventJsImpl {
  /// The event type.
  external String get type;

  /// The `MapLibreMap` object that fired the event.
  external MapLibreMapJsImpl get target;

  /// The DOM event which caused the map event.
  external MouseEvent get originalEvent;

  /// The pixel coordinates of the mouse cursor, relative to the map and measured from the top left corner.
  external PointJsImpl get point;

  /// The geographic location on the map of the mouse cursor.
  external LngLatJsImpl get lngLat;

  ///  Prevents subsequent default processing of the event by the map.
  ///
  ///  Calling this method will prevent the following default map behaviors:
  ///
  ///  *  On `mousedown` events, the behavior of {@link DragPanHandler}
  ///  *  On `mousedown` events, the behavior of {@link DragRotateHandler}
  ///  *  On `mousedown` events, the behavior of {@link BoxZoomHandler}
  ///  *  On `dblclick` events, the behavior of {@link DoubleClickZoomHandler}
  external preventDefault();

  /// `true` if `preventDefault` has been called.
  external bool get defaultPrevented;
}

@JS()
@anonymous
abstract class MapTouchEventJsImpl {
  /// The event type.
  external String get type;

  /// The `MapLibreMap` object that fired the event.
  external MapLibreMapJsImpl get target;

  /// The DOM event which caused the map event.
  external TouchEvent get originalEvent;

  /// The geographic location on the map of the center of the touch event points.
  external LngLatJsImpl get lngLat;

  /// The pixel coordinates of the center of the touch event points, relative to the map and measured from the top left
  /// corner.
  external PointJsImpl get point;

  ///  The array of pixel coordinates corresponding to a
  ///  [touch event's `touches`](https://developer.mozilla.org/en-US/docs/Web/API/TouchEvent/touches) property.
  external List<PointJsImpl> get points;

  ///  The geographical locations on the map corresponding to a
  ///  [touch event's `touches`](https://developer.mozilla.org/en-US/docs/Web/API/TouchEvent/touches) property.
  external List<LngLatJsImpl> get lngLats;

  ///  Prevents subsequent default processing of the event by the map.
  ///
  ///  Calling this method will prevent the following default map behaviors:
  ///
  ///  *  On `touchstart` events, the behavior of {@link DragPanHandler}
  ///  *  On `touchstart` events, the behavior of {@link TouchZoomRotateHandler}
  external preventDefault();

  ///  `true` if `preventDefault` has been called.
  external bool get defaultPrevented;
}
