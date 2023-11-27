library maplibre.interop.style.layers.symbol_layer;

import 'package:js/js_util.dart';
import 'package:maplibre_gl_web/src/style/layers/symbol_layer.dart';

class SymbolLayerJsImpl {
  static toJs(SymbolLayer symbolLayer) => jsify(toDict(symbolLayer));

  static toDict(SymbolLayer symbolLayer) {
    Map<String, dynamic> dict = {
      'id': symbolLayer.id,
      'type': 'symbol',
    };
    if (symbolLayer.metadata != null) {
      dict['metadata'] = symbolLayer.metadata;
    }
    if (symbolLayer.source != null) {
      dict['source'] = symbolLayer.source is String
          ? symbolLayer.source
          : symbolLayer.source.dict;
    }
    if (symbolLayer.sourceLayer != null) {
      dict['source-layer'] = symbolLayer.sourceLayer;
    }
    if (symbolLayer.minZoom != null) {
      dict['minzoom'] = symbolLayer.minZoom;
    }
    if (symbolLayer.maxZoom != null) {
      dict['maxzoom'] = symbolLayer.maxZoom;
    }
    if (symbolLayer.filter != null) {
      dict['filter'] = symbolLayer.filter;
    }
    if (symbolLayer.layout != null) {
      dict['layout'] = symbolLayer.layout!.dict;
    }
    if (symbolLayer.paint != null) {
      dict['paint'] = symbolLayer.paint!.dict;
    }
    return dict;
  }
}

class SymbolPaintJsImpl {
  static toJs(SymbolPaint symbolPaint) => jsify(toDict(symbolPaint));

  static toDict(SymbolPaint symbolPaint) {
    Map<String, dynamic> dict = {};
    if (symbolPaint.iconOpacity != null) {
      dict['icon-opacity'] = symbolPaint.iconOpacity;
    }
    if (symbolPaint.iconColor != null) {
      dict['icon-color'] = symbolPaint.iconColor;
    }
    if (symbolPaint.iconHaloColor != null) {
      dict['icon-halo-color'] = symbolPaint.iconHaloColor;
    }
    if (symbolPaint.iconHaloWidth != null) {
      dict['icon-halo-width'] = symbolPaint.iconHaloWidth;
    }
    if (symbolPaint.iconHaloBlur != null) {
      dict['icon-halo-blur'] = symbolPaint.iconHaloBlur;
    }
    if (symbolPaint.iconTranslate != null) {
      dict['icon-translate'] = symbolPaint.iconTranslate;
    }
    if (symbolPaint.iconTranslateAnchor != null) {
      dict['icon-translate-anchor'] = symbolPaint.iconTranslateAnchor;
    }
    if (symbolPaint.textOpacity != null) {
      dict['text-opacity'] = symbolPaint.textOpacity;
    }
    if (symbolPaint.textColor != null) {
      dict['text-color'] = symbolPaint.textColor;
    }
    if (symbolPaint.textHaloColor != null) {
      dict['text-halo-color'] = symbolPaint.textHaloColor;
    }
    if (symbolPaint.textHaloWidth != null) {
      dict['text-halo-width'] = symbolPaint.textHaloWidth;
    }
    if (symbolPaint.textHaloBlur != null) {
      dict['text-halo-blur'] = symbolPaint.textHaloBlur;
    }
    if (symbolPaint.textTranslate != null) {
      dict['text-translate'] = symbolPaint.textTranslate;
    }
    if (symbolPaint.textTranslateAnchor != null) {
      dict['text-translate-anchor'] = symbolPaint.textTranslateAnchor;
    }
    return dict;
  }
}

class SymbolLayoutJsImpl {
  static toJs(SymbolLayout symbolLayout) => jsify(toDict(symbolLayout));

  static toDict(SymbolLayout symbolLayout) {
    Map<String, dynamic> dict = {};
    if (symbolLayout.symbolAvoidEdges != null) {
      dict['symbol-avoid-edges'] = symbolLayout.symbolAvoidEdges;
    }
    if (symbolLayout.symbolSortKey != null) {
      dict['symbol-sort-key'] = symbolLayout.symbolSortKey;
    }
    if (symbolLayout.symbolZOrder != null) {
      dict['symbol-z-order'] = symbolLayout.symbolZOrder;
    }
    if (symbolLayout.iconAllowOverlap != null) {
      dict['icon-allow-overlap'] = symbolLayout.iconAllowOverlap;
    }
    if (symbolLayout.iconIgnorePlacement != null) {
      dict['icon-ignore-placement'] = symbolLayout.iconIgnorePlacement;
    }
    if (symbolLayout.iconOptional != null) {
      dict['icon-optional'] = symbolLayout.iconOptional;
    }
    if (symbolLayout.iconRotationAlignment != null) {
      dict['icon-rotation-alignment'] = symbolLayout.iconRotationAlignment;
    }
    if (symbolLayout.iconSize != null) {
      dict['icon-size'] = symbolLayout.iconSize;
    }
    if (symbolLayout.iconTextFit != null) {
      dict['icon-text-fit'] = symbolLayout.iconTextFit;
    }
    if (symbolLayout.iconFitPadding != null) {
      dict['icon-fit-padding'] = symbolLayout.iconFitPadding;
    }
    if (symbolLayout.iconImage != null) {
      dict['icon-image'] = symbolLayout.iconImage;
    }
    if (symbolLayout.iconRotate != null) {
      dict['icon-rotate'] = symbolLayout.iconRotate;
    }
    if (symbolLayout.iconPadding != null) {
      dict['icon-padding'] = symbolLayout.iconPadding;
    }
    if (symbolLayout.iconKeepUpright != null) {
      dict['icon-keep-upright'] = symbolLayout.iconKeepUpright;
    }
    if (symbolLayout.iconOffset != null) {
      dict['icon-offset'] = symbolLayout.iconOffset;
    }
    if (symbolLayout.iconAnchor != null) {
      dict['icon-anchor'] = symbolLayout.iconAnchor;
    }
    if (symbolLayout.iconPitchAlignment != null) {
      dict['icon-pitch-alignment'] = symbolLayout.iconPitchAlignment;
    }
    if (symbolLayout.textPitchAlignment != null) {
      dict['text-pitch-alignment'] = symbolLayout.textPitchAlignment;
    }
    if (symbolLayout.textRotationAlignment != null) {
      dict['text-rotation-alignment'] = symbolLayout.textRotationAlignment;
    }
    if (symbolLayout.textField != null) {
      dict['text-field'] = symbolLayout.textField;
    }
    if (symbolLayout.textFont != null) {
      dict['text-font'] = symbolLayout.textFont;
    }
    if (symbolLayout.textSize != null) {
      dict['text-size'] = symbolLayout.textSize;
    }
    if (symbolLayout.textMaxWidth != null) {
      dict['text-max-width'] = symbolLayout.textMaxWidth;
    }
    if (symbolLayout.textLineHeight != null) {
      dict['text-line-height'] = symbolLayout.textLineHeight;
    }
    if (symbolLayout.textLetterSpacing != null) {
      dict['text-letter-spacing'] = symbolLayout.textLetterSpacing;
    }
    if (symbolLayout.textJustify != null) {
      dict['text-justify'] = symbolLayout.textJustify;
    }
    if (symbolLayout.textRadialOffset != null) {
      dict['text-radial-offset'] = symbolLayout.textRadialOffset;
    }
    if (symbolLayout.textVariableAnchor != null) {
      dict['text-variable-anchor'] = symbolLayout.textVariableAnchor;
    }
    if (symbolLayout.textAnchor != null) {
      dict['text-anchor'] = symbolLayout.textAnchor;
    }
    if (symbolLayout.textMaxAngle != null) {
      dict['text-max-angle'] = symbolLayout.textMaxAngle;
    }
    if (symbolLayout.textWritingMode != null) {
      dict['text-writing-mode'] = symbolLayout.textWritingMode;
    }
    if (symbolLayout.textRotate != null) {
      dict['text-rotate'] = symbolLayout.textRotate;
    }
    if (symbolLayout.textPadding != null) {
      dict['text-padding'] = symbolLayout.textPadding;
    }
    if (symbolLayout.textKeepUpright != null) {
      dict['text-keep-upright'] = symbolLayout.textKeepUpright;
    }
    if (symbolLayout.textTransform != null) {
      dict['text-transform'] = symbolLayout.textTransform;
    }
    if (symbolLayout.textOffset != null) {
      dict['text-offset'] = symbolLayout.textOffset;
    }
    if (symbolLayout.textAllowOverlap != null) {
      dict['text-allow-overlap'] = symbolLayout.textAllowOverlap;
    }
    if (symbolLayout.textIgnorePlacement != null) {
      dict['text-ignore-placement'] = symbolLayout.textIgnorePlacement;
    }
    if (symbolLayout.textOptional != null) {
      dict['text-optional'] = symbolLayout.textOptional;
    }
    if (symbolLayout.visibility != null) {
      dict['visibility'] = symbolLayout.visibility;
    }
    return dict;
  }
}
