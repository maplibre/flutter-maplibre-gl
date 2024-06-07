library maplibre.style.sources.source;

abstract class Source<T> {
  final T jsObject;

  /// Creates a new JsObjectWrapper type from a [jsObject].
  Source.fromJsObject(this.jsObject);

  /// Dict object.
  Map<String, dynamic> get dict => throw Exception('dict not implemented!');
}
