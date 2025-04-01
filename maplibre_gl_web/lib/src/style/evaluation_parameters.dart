import 'package:maplibre_gl_web/src/interop/interop.dart';

class EvaluationParameters extends JsObjectWrapper<EvaluationParametersJsImpl> {
  factory EvaluationParameters(num zoom, [dynamic options]) =>
      EvaluationParameters.fromJsObject(
        EvaluationParametersJsImpl(zoom, options),
      );

  /// Creates a new EvaluationParameters from a [jsObject].
  EvaluationParameters.fromJsObject(super.jsObject) : super.fromJsObject();
  num get zoom => jsObject.zoom;
  num get now => jsObject.now;
  num get fadeDuration => jsObject.fadeDuration;
  dynamic get zoomHistory => jsObject.zoomHistory;
  dynamic get transition => jsObject.transition;

  bool isSupportedScript(String str) => jsObject.isSupportedScript(str);

  dynamic crossFadingFactor() => jsObject.crossFadingFactor();

  dynamic getCrossfadeParameters() => jsObject.getCrossfadeParameters();
}
