import 'package:maplibre_gl_web/src/interop/style/layers/line_layer_interop.dart';
import 'package:maplibre_gl_web/src/style/layers/layer.dart';

class LineLayer extends Layer {
  LineLayer({
    required this.id,
    this.source,
    this.sourceLayer,
    this.paint,
    this.layout,
    this.filter,
  });
  String id;

  /// Source or String
  dynamic source;
  String? sourceLayer;
  LinePaint? paint;
  LineLayout? layout;
  dynamic filter;

  @override
  dynamic get jsObject => LineLayerJsImpl.toJs(this);

  @override
  Map<String, dynamic> get dict => LineLayerJsImpl.toDict(this);
}

class LinePaint {
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

  dynamic get jsObject => LinePaintJsImpl.toJs(this);

  Map<String, dynamic> get dict => LinePaintJsImpl.toDict(this);
}

class LineLayout {
  LineLayout({
    this.lineCap,
    this.lineJoin,
    this.lineMiterLimit,
    this.lineRoundLimit,
    this.lineSortKey,
    this.visibility,
  });
  String? lineCap;
  String? lineJoin;
  num? lineMiterLimit;
  num? lineRoundLimit;
  num? lineSortKey;
  String? visibility;

  dynamic get jsObject => LineLayoutJsImpl.toJs(this);

  Map<String, dynamic> get dict => LineLayoutJsImpl.toDict(this);
}
