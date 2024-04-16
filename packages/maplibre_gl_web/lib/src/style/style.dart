library maplibre.style.style;

import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/style/evaluation_parameters.dart';
import 'package:maplibre_gl_web/src/style/style_image.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

class StyleSetterOptions extends JsObjectWrapper<StyleSetterOptionsJsImpl> {
  bool get validate => jsObject.validate;

  /// Creates a new StyleSetterOptions from a [jsObject].
  StyleSetterOptions.fromJsObject(StyleSetterOptionsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

class Style extends JsObjectWrapper<StyleJsImpl> {
  loadURL(String url, dynamic options) => jsObject.loadURL(url, options);

  loadJSON(dynamic json, StyleSetterOptions option) =>
      jsObject.loadJSON(json, option.jsObject);

  loaded() => jsObject.loaded();

  hasTransitions() => jsObject.hasTransitions();

  ///  Apply queued style updates in a batch and recalculate zoom-dependent paint properties.
  update(EvaluationParameters parameters) =>
      jsObject.update(parameters.jsObject);

  ///  Update this style's state to match the given style JSON, performing only
  ///  the necessary mutations.
  ///
  ///  May throw an Error ('Unimplemented: METHOD') if the maplibre-gl-style-spec
  ///  diff algorithm produces an operation that is not supported.
  ///
  ///  @returns {boolean} true if any changes were made; false otherwise
  ///  @private
  setState(dynamic nextState) => jsObject.setState(nextState);

  addImage(String id, StyleImage image) =>
      jsObject.addImage(id, image.jsObject);

  updateImage(String id, StyleImage image) =>
      jsObject.updateImage(id, image.jsObject);

  StyleImage getImage(String id) =>
      StyleImage.fromJsObject(jsObject.getImage(id));

  removeImage(String id) => jsObject.removeImage(id);

  listImages() => jsObject.listImages();

  addSource(String id, dynamic source, StyleSetterOptions options) =>
      jsObject.addSource(id, source, options.jsObject);

  ///  Remove a source from this stylesheet, given its id.
  ///  @param {string} id id of the source to remove
  ///  @throws {Error} if no source is found with the given ID
  removeSource(String id) => jsObject.removeSource(id);

  ///  Set the data of a GeoJSON source, given its id.
  ///  @param {string} id id of the source
  ///  @param {GeoJSON|string} data GeoJSON source
  setGeoJSONSourceData(String id, dynamic data) =>
      jsObject.setGeoJSONSourceData(id, data);

  ///  Get a source by id.
  ///  @param {string} id id of the desired source
  ///  @returns {Object} source
  dynamic getSource(String id) => jsObject.getSource(id);

  ///  Add a layer to the map style. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} [before] ID of an existing layer to insert before
  addLayer(dynamic layerObject,
          [String? before, StyleSetterOptions? options]) =>
      jsObject.addLayer(layerObject);

  ///  Moves a layer to a different z-position. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} id  ID of the layer to move
  ///  @param {string} [before] ID of an existing layer to insert before
  moveLayer(String id, [String? before]) => jsObject.moveLayer(id);

  ///  Remove the layer with the given id from the style.
  ///
  ///  If no such layer exists, an `error` event is fired.
  ///
  ///  @param {string} id id of the layer to remove
  ///  @fires error
  removeLayer(String id) => jsObject.removeLayer(id);

  ///  Return the style layer object with the given `id`.
  ///
  ///  @param {string} id - id of the desired layer
  ///  @returns {?Object} a layer, if one with the given `id` exists
  dynamic getLayer(String id) => jsObject.getLayer(id);

  setLayerZoomRange(String layerId, [num? minzoom, num? maxzoom]) =>
      jsObject.setLayerZoomRange(layerId);

  setFilter(String layerId, dynamic filter, StyleSetterOptions options) =>
      jsObject.setFilter(layerId, filter, options.jsObject);

  ///  Get a layer's filter object
  ///  @param {string} layer the layer to inspect
  ///  @returns {*} the layer's filter, if any
  getFilter(String layer) => jsObject.getFilter(layer);

  setLayoutProperty(String layerId, String name, dynamic value,
          StyleSetterOptions options) =>
      jsObject.setLayoutProperty(layerId, name, value, options.jsObject);

  ///  Get a layout property's value from a given layer
  ///  @param {string} layerId the layer to inspect
  ///  @param {string} name the name of the layout property
  ///  @returns {*} the property value
  getLayoutProperty(String layerId, String name) =>
      jsObject.getLayoutProperty(layerId, name);

  setPaintProperty(String layerId, String name, dynamic value,
          StyleSetterOptions options) =>
      jsObject.setPaintProperty(layerId, name, value, options.jsObject);

  getPaintProperty(String layer, String name) =>
      jsObject.getPaintProperty(layer, name);

  setFeatureState(dynamic target, dynamic state) =>
      jsObject.setFeatureState(target, state);

  removeFeatureState(dynamic target, [String? key]) =>
      jsObject.removeFeatureState(target);

  getFeatureState(dynamic target) => jsObject.getFeatureState(target);

  getTransition() => jsObject.getTransition();

  serialize() => jsObject.serialize();

  querySourceFeatures(String sourceID, dynamic params) =>
      jsObject.querySourceFeatures(sourceID, params);

  addSourceType(String name, dynamic sourceType, Function callback) =>
      jsObject.addSourceType(name, sourceType, callback);

  getLight() => jsObject.getLight();

  setLight(dynamic lightOptions, StyleSetterOptions options) =>
      jsObject.setLight(lightOptions, options.jsObject);

  // Callbacks from web workers

  getImages(String mapId, dynamic params, Function callback) =>
      jsObject.getImages(mapId, params, callback);

  getGlyphs(String mapId, dynamic params, Function callback) =>
      jsObject.getGlyphs(mapId, params, callback);

  getResource(String mapId, RequestParameters params, Function callback) =>
      jsObject.getResource(mapId, params.jsObject, callback);

  /// Creates a new Style from a [jsObject].
  Style.fromJsObject(StyleJsImpl jsObject) : super.fromJsObject(jsObject);

  List<dynamic> get layers => jsObject.layers;
}

class StyleFunction extends JsObjectWrapper<StyleFunctionJsImpl> {
  factory StyleFunction({
    dynamic base,
    dynamic stops,
  }) =>
      StyleFunction.fromJsObject(StyleFunctionJsImpl(base: base, stops: stops));

  /// Creates a new StyleFunction from a [jsObject].
  StyleFunction.fromJsObject(StyleFunctionJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
