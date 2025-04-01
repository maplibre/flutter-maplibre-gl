abstract class Source<T> {
  /// Creates a new JsObjectWrapper type from a [jsObject].
  Source.fromJsObject(this.jsObject);
  final T jsObject;

  /// Dict object.
  Map<String, dynamic> get dict => throw Exception('dict not implemented!');
}
