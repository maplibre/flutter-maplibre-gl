import 'package:js/js_util.dart';
import 'package:maplibre_gl_web/src/style/layers/circle_layer.dart';

class CircleLayerJsImpl {
  static dynamic toJs(CircleLayer circleLayer) => jsify(toDict(circleLayer));

  static Map<String, dynamic> toDict(CircleLayer circleLayer) {
    final dict = <String, dynamic>{
      'id': circleLayer.id,
      'type': 'circle',
    };
    if (circleLayer.source != null) {
      dict['source'] = circleLayer.source is String
          ? circleLayer.source
          : circleLayer.source.dict;
    }
    if (circleLayer.sourceLayer != null) {
      dict['source-layer'] = circleLayer.sourceLayer;
    }
    if (circleLayer.paint != null) {
      dict['paint'] = circleLayer.paint!.dict;
    }
    return dict;
  }
}

class CirclePaintJsImpl {
  static dynamic toJs(CirclePaint circlePaint) => jsify(toDict(circlePaint));

  static Map<String, dynamic> toDict(CirclePaint circlePaint) {
    final dict = <String, dynamic>{};
    if (circlePaint.circleRadius != null) {
      dict['circle-radius'] = circlePaint.circleRadius;
    }
    if (circlePaint.circleColor != null) {
      dict['circle-color'] = circlePaint.circleColor;
    }
    return dict;
  }
}
