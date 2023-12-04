library maplibre.style.evaluation_parameters;

import 'package:maplibre_gl_web/src/interop/interop.dart';

class EvaluationParameters extends JsObjectWrapper<EvaluationParametersJsImpl> {
  num get zoom => jsObject.zoom;
  num get now => jsObject.now;
  num get fadeDuration => jsObject.fadeDuration;
  dynamic get zoomHistory => jsObject.zoomHistory;
  dynamic get transition => jsObject.transition;

  factory EvaluationParameters(num zoom, [dynamic options]) =>
      EvaluationParameters.fromJsObject(
          EvaluationParametersJsImpl(zoom, options));

  bool isSupportedScript(String str) => jsObject.isSupportedScript(str);

  crossFadingFactor() => jsObject.crossFadingFactor();

  dynamic getCrossfadeParameters() => jsObject.getCrossfadeParameters();

  /// Creates a new EvaluationParameters from a [jsObject].
  EvaluationParameters.fromJsObject(EvaluationParametersJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
