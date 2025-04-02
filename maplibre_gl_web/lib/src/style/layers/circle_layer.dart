import 'package:maplibre_gl_web/src/interop/style/layers/circle_layer_interop.dart';
import 'package:maplibre_gl_web/src/style/layers/layer.dart';

class CircleLayer extends Layer {
  CircleLayer({
    required this.id,
    this.source,
    this.paint,
    this.sourceLayer,
  });
  String id;

  /// Source or String
  dynamic source;
  CirclePaint? paint;
  dynamic sourceLayer;

  @override
  dynamic get jsObject => CircleLayerJsImpl.toJs(this);

  @override
  Map<String, dynamic> get dict => CircleLayerJsImpl.toDict(this);
}

class CirclePaint {
  CirclePaint({
    this.circleRadius,
    this.circleColor,
  });
  dynamic circleRadius;
  dynamic circleColor;

  dynamic get jsObject => CirclePaintJsImpl.toJs(this);

  Map<String, dynamic> get dict => CirclePaintJsImpl.toDict(this);
}
