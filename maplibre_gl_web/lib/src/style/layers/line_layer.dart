library maplibre.style.layers.line_layer;

import 'package:maplibre_gl_web/src/interop/style/layers/line_layer_interop.dart';
import 'package:maplibre_gl_web/src/style/layers/layer.dart';

class LineLayer extends Layer {
  String id;

  /// Source or String
  dynamic source;
  String? sourceLayer;
  LinePaint? paint;
  LineLayout? layout;
  dynamic filter;

  LineLayer({
    required this.id,
    this.source,
    this.sourceLayer,
    this.paint,
    this.layout,
    this.filter,
  });

  @override
  get jsObject => LineLayerJsImpl.toJs(this);

  @override
  get dict => LineLayerJsImpl.toDict(this);
}

class LinePaint {
  num? lineOpacity;
  dynamic lineColor;
  List<num>? lineTranslate;
  String? lineTranslateAnchor;
  dynamic lineWidth;
  num? lineGapWidth;
  num? lineOffset;
  num? lineBlur;
  List<num>? lineDasharray;
  String? linePattern;
  String? lineGradient;

  LinePaint({
    this.lineOpacity,
    this.lineColor,
    this.lineTranslate,
    this.lineTranslateAnchor,
    this.lineWidth,
    this.lineGapWidth,
    this.lineOffset,
    this.lineBlur,
    this.lineDasharray,
    this.linePattern,
    this.lineGradient,
  });

  get jsObject => LinePaintJsImpl.toJs(this);

  get dict => LinePaintJsImpl.toDict(this);
}

class LineLayout {
  String? lineCap;
  String? lineJoin;
  num? lineMiterLimit;
  num? lineRoundLimit;
  num? lineSortKey;
  String? visibility;

  LineLayout({
    this.lineCap,
    this.lineJoin,
    this.lineMiterLimit,
    this.lineRoundLimit,
    this.lineSortKey,
    this.visibility,
  });

  get jsObject => LineLayoutJsImpl.toJs(this);

  get dict => LineLayoutJsImpl.toDict(this);
}
