library maplibre.style.layers.layer;

abstract class Layer {
  /// JS object.
  dynamic get jsObject => throw Exception('jsObject not implemented!');

  /// Dict object.
  Map<String, dynamic> get dict => throw Exception('dict not implemented!');
}
