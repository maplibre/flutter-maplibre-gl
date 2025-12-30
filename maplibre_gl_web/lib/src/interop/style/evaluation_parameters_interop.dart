@JS('maplibregl')
library;

import 'dart:js_interop';

@JS('EvaluationParameters')
@staticInterop
class EvaluationParametersJsImpl {
  external factory EvaluationParametersJsImpl(num zoom, [JSAny? options]);
}

extension EvaluationParametersJsImplExtension on EvaluationParametersJsImpl {
  external num get zoom;
  external num get now;
  external num get fadeDuration;
  external JSAny? get zoomHistory;
  external JSAny? get transition;

  external bool isSupportedScript(String str);

  external JSAny? crossFadingFactor();

  external JSAny? getCrossfadeParameters();
}
