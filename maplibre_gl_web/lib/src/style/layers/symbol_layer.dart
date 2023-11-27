library maplibre.style.layers.symbol_layer;

import 'package:maplibre_gl_web/src/interop/style/layers/symbol_layer_interop.dart';
import 'package:maplibre_gl_web/src/style/layers/layer.dart';

class SymbolLayer extends Layer {
  String id;
  String? metadata;

  /// Source or String
  dynamic source;
  String? sourceLayer;
  num? minZoom;
  num? maxZoom;
  dynamic filter;
  SymbolLayout? layout;
  SymbolPaint? paint;

  SymbolLayer({
    required this.id,
    this.metadata,
    this.source,
    this.sourceLayer,
    this.minZoom,
    this.maxZoom,
    this.filter,
    this.layout,
    this.paint,
  });

  @override
  get jsObject => SymbolLayerJsImpl.toJs(this);

  @override
  get dict => SymbolLayerJsImpl.toDict(this);
}

class SymbolPaint {
  num? iconOpacity;
  String? iconColor;
  String? iconHaloColor;
  num? iconHaloWidth;
  num? iconHaloBlur;
  List<num>? iconTranslate;
  String? iconTranslateAnchor;
  num? textOpacity;
  String? textColor;
  String? textHaloColor;
  num? textHaloWidth;
  num? textHaloBlur;
  List<num>? textTranslate;
  String? textTranslateAnchor;

  SymbolPaint({
    this.iconOpacity,
    this.iconColor,
    this.iconHaloColor,
    this.iconHaloWidth,
    this.iconHaloBlur,
    this.iconTranslate,
    this.iconTranslateAnchor,
    this.textOpacity,
    this.textColor,
    this.textHaloColor,
    this.textHaloWidth,
    this.textHaloBlur,
    this.textTranslate,
    this.textTranslateAnchor,
  });

  get jsObject => SymbolPaintJsImpl.toJs(this);

  get dict => SymbolPaintJsImpl.toDict(this);
}

class SymbolLayout {
  bool? symbolAvoidEdges;
  num? symbolSortKey;
  String? symbolZOrder;
  bool? iconAllowOverlap;
  bool? iconIgnorePlacement;
  bool? iconOptional;
  String? iconRotationAlignment;
  num? iconSize;
  String? iconTextFit;
  List<num>? iconFitPadding;
  dynamic iconImage;
  num? iconRotate;
  num? iconPadding;
  bool? iconKeepUpright;
  List<num>? iconOffset;
  String? iconAnchor;
  String? iconPitchAlignment;
  String? textPitchAlignment;
  String? textRotationAlignment;
  String? textField;
  List<String>? textFont;
  num? textSize;
  num? textMaxWidth;
  num? textLineHeight;
  num? textLetterSpacing;
  String? textJustify;
  num? textRadialOffset;
  List<String>? textVariableAnchor;
  String? textAnchor;
  num? textMaxAngle;
  List<String>? textWritingMode;
  num? textRotate;
  num? textPadding;
  bool? textKeepUpright;
  String? textTransform;
  List<num>? textOffset;
  bool? textAllowOverlap;
  bool? textIgnorePlacement;
  bool? textOptional;
  String? visibility;

  SymbolLayout({
    this.symbolAvoidEdges,
    this.symbolSortKey,
    this.symbolZOrder,
    this.iconAllowOverlap,
    this.iconIgnorePlacement,
    this.iconOptional,
    this.iconRotationAlignment,
    this.iconSize,
    this.iconTextFit,
    this.iconFitPadding,
    this.iconImage,
    this.iconRotate,
    this.iconPadding,
    this.iconKeepUpright,
    this.iconOffset,
    this.iconAnchor,
    this.iconPitchAlignment,
    this.textPitchAlignment,
    this.textRotationAlignment,
    this.textField,
    this.textFont,
    this.textSize,
    this.textMaxWidth,
    this.textLineHeight,
    this.textLetterSpacing,
    this.textJustify,
    this.textRadialOffset,
    this.textVariableAnchor,
    this.textAnchor,
    this.textMaxAngle,
    this.textWritingMode,
    this.textRotate,
    this.textPadding,
    this.textKeepUpright,
    this.textTransform,
    this.textOffset,
    this.textAllowOverlap,
    this.textIgnorePlacement,
    this.textOptional,
    this.visibility,
  });

  get jsObject => SymbolLayoutJsImpl.toJs(this);

  get dict => SymbolLayoutJsImpl.toDict(this);
}
