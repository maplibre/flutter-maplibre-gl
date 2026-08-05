// This file must stay alone and must never initialize the binding: the absence
// of one is the condition under test. `flutter_test` only creates a binding
// when something asks for it, so a single `testWidgets`, a `TestDefaultBinary
// MessengerBinding` call, or anything else touching the binding added here
// would make this test pass no matter what MapLibreMap.preWarm() does.
//
// Regression test for the "Binding has not yet been initialized" crash: the
// method is documented as the first thing in `main()`, before `runApp()`, and
// on Android and iOS it reaches native over a method channel, which resolves
// its messenger through ServicesBinding.instance.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  test('preWarm can be called before the binding exists', () async {
    // Self-defense against the neutering described above: if anything in this
    // file ever initializes a binding before this point, fail loudly instead
    // of silently testing nothing. debugBindingType() is null until a binding
    // exists; under `flutter test` asserts are on, so the value is populated.
    expect(
      BindingBase.debugBindingType(),
      isNull,
      reason:
          'a binding exists before preWarm ran, so this test no longer '
          'exercises the no-binding path and must be restored to a file '
          'where nothing touches the binding',
    );
    await expectLater(MapLibreMap.preWarm(), completes);
  });
}
