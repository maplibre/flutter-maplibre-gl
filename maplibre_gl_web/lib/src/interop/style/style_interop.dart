@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/js.dart';
import 'package:maplibre_gl_web/src/interop/style/evaluation_parameters_interop.dart';
import 'package:maplibre_gl_web/src/interop/style/style_image_interop.dart';
import 'package:maplibre_gl_web/src/interop/style/style_layer_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

@JS()
@staticInterop
abstract class StyleSetterOptionsJsImpl {}

extension StyleSetterOptionsJsImplExtension on StyleSetterOptionsJsImpl {
  external bool get validate;
}

@JS('Style')
@staticInterop
abstract class StyleJsImpl extends EventedJsImpl {}

extension StyleJsImplExtension on StyleJsImpl {
  external void loadURL(String url, JSAny options);

  external void loadJSON(JSAny json, StyleSetterOptionsJsImpl option);

  external void loaded();

  external void hasTransitions();

  ///  Apply queued style updates in a batch and recalculate zoom-dependent paint properties.
  external void update(EvaluationParametersJsImpl parameters);

  ///  Update this style's state to match the given style JSON, performing only
  ///  the necessary mutations.
  ///
  ///  May throw an Error ('Unimplemented: METHOD') if the maplibre-gl-style-spec
  ///  diff algorithm produces an operation that is not supported.
  ///
  ///  @returns {boolean} true if any changes were made; false otherwise
  ///  @private
  external void setState(JSAny nextState);

  external void addImage(String id, StyleImageJsImpl image);

  external void updateImage(String id, StyleImageJsImpl image);

  external StyleImageJsImpl getImage(String id);

  external void removeImage(String id);

  external void listImages();

  external void addSource(
      String id, JSAny source, StyleSetterOptionsJsImpl options);

  ///  Remove a source from this stylesheet, given its id.
  ///  @param {string} id id of the source to remove
  ///  @throws {Error} if no source is found with the given ID
  external void removeSource(String id);

  ///  Set the data of a GeoJSON source, given its id.
  ///  @param {string} id id of the source
  ///  @param {GeoJSON|string} data GeoJSON source
  external void setGeoJSONSourceData(String id, JSAny data);

  ///  Get a source by id.
  ///  @param {string} id id of the desired source
  ///  @returns {Object} source
  external JSAny getSource(String id);

  ///  Add a layer to the map style. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} [before] ID of an existing layer to insert before
  external void addLayer(JSAny layerObject,
      [String? before, StyleSetterOptionsJsImpl? options]);

  ///  Moves a layer to a different z-position. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} id  ID of the layer to move
  ///  @param {string} [before] ID of an existing layer to insert before
  external void moveLayer(String id, [String? before]);

  ///  Remove the layer with the given id from the style.
  ///
  ///  If no such layer exists, an `error` event is fired.
  ///
  ///  @param {string} id id of the layer to remove
  ///  @fires error
  external void removeLayer(String id);

  ///  Return the style layer object with the given `id`.
  ///
  ///  @param {string} id - id of the desired layer
  ///  @returns {?Object} a layer, if one with the given `id` exists
  external JSAny getLayer(String id);

  external void setLayerZoomRange(String layerId, [num? minzoom, num? maxzoom]);

  external void setFilter(
      String layerId, JSAny filter, StyleSetterOptionsJsImpl options);

  ///  Get a layer's filter object
  ///  @param {string} layer the layer to inspect
  ///  @returns {*} the layer's filter, if any
  external JSAny getFilter(String layer);

  external void setLayoutProperty(String layerId, String name, JSAny value,
      StyleSetterOptionsJsImpl options);

  ///  Get a layout property's value from a given layer
  ///  @param {string} layerId the layer to inspect
  ///  @param {string} name the name of the layout property
  ///  @returns {*} the property value
  external JSAny getLayoutProperty(String layerId, String name);

  external void setPaintProperty(String layerId, String name, JSAny value,
      StyleSetterOptionsJsImpl options);

  external JSAny getPaintProperty(String layer, String name);

  external void setFeatureState(JSAny target, JSAny state);

  external void removeFeatureState(JSAny target, [String? key]);

  external JSAny getFeatureState(JSAny target);

  external JSAny getTransition();

  external JSAny serialize();

  external JSAny querySourceFeatures(String sourceID, JSAny params);

  external void addSourceType(
      String name, JSAny sourceType, JSFunction callback);

  external JSAny getLight();

  external void setLight(JSAny lightOptions, StyleSetterOptionsJsImpl options);

  // Callbacks from web workers

  external void getImages(String mapId, JSAny params, JSFunction callback);

  external void getGlyphs(String mapId, JSAny params, JSFunction callback);

  external void getResource(
      String mapId, RequestParametersJsImpl params, JSFunction callback);

  external JSArray<StyleLayerJsImpl> get layers;

  /// Map of source IDs to source objects
  external JSObject? get sources;
}

@JS()
@staticInterop
class StyleFunctionJsImpl {
  factory StyleFunctionJsImpl() => createJsObject() as StyleFunctionJsImpl;
}

extension StyleFunctionJsImplExtension on StyleFunctionJsImpl {
  external JSAny? get base;
  external set base(JSAny? value);

  external JSAny? get stops;
  external set stops(JSAny? value);
}
