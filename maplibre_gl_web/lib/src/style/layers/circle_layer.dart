library maplibre.style.layers.circle_layer;

import 'package:maplibre_gl_web/src/interop/style/layers/circle_layer_interop.dart';
import 'package:maplibre_gl_web/src/style/layers/layer.dart';

class CircleLayer extends Layer {
  String id;

  /// Source or String
  dynamic source;
  CirclePaint? paint;
  dynamic sourceLayer;

  CircleLayer({
    required this.id,
    this.source,
    this.paint,
    this.sourceLayer,
  });

  @override
  get jsObject => CircleLayerJsImpl.toJs(this);

  @override
  get dict => CircleLayerJsImpl.toDict(this);
}

class CirclePaint {
  dynamic circleRadius;
  dynamic circleColor;

  CirclePaint({
    this.circleRadius,
    this.circleColor,
  });

  get jsObject => CirclePaintJsImpl.toJs(this);

  get dict => CirclePaintJsImpl.toDict(this);
}
