@JS('maplibregl')
library maplibre.interop.style.evaluation_parameters;

import 'package:js/js.dart';

@JS('EvaluationParameters')
class EvaluationParametersJsImpl {
  external factory EvaluationParametersJsImpl(num zoom, [dynamic options]);
  external num get zoom;
  external num get now;
  external num get fadeDuration;
  external dynamic get zoomHistory;
  external dynamic get transition;

  external bool isSupportedScript(String str);

  external dynamic crossFadingFactor();

  external dynamic getCrossfadeParameters();
}
