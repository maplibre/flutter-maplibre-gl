// Reads the LICENSE file from disk, so it cannot run in a browser, where
// `melos run test:web` also executes this package's tests.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter's license collector concatenates every package's LICENSE file into
/// the app's NOTICES bundle, separating them with a line of exactly 80 dashes.
/// At runtime it splits on that line and reads each block's leading lines, up
/// to the first blank line, as the package names shown on the Licenses screen.
///
/// A LICENSE file that contains such a line therefore gets cut in two, and the
/// tail is attributed to a package name that does not exist. Ours used one as
/// an internal rule, which showed up as a blank entry on every app's Licenses
/// screen with the d3-color text behind it (#895).
///
/// This is invisible when reading the file, so it is asserted here rather than
/// left to be rediscovered.
void main() {
  const flutterLicenseSeparator =
      '--------------------------------------------------------------------------------';

  test("LICENSE does not contain Flutter's license separator", () {
    final license = File('LICENSE');
    expect(
      license.existsSync(),
      isTrue,
      reason: 'LICENSE is missing from the published package',
    );

    final offending = <int>[];
    final lines = license.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimRight() == flutterLicenseSeparator) {
        offending.add(i + 1);
      }
    }

    expect(
      offending,
      isEmpty,
      reason:
          'LICENSE line(s) $offending are exactly 80 dashes, which Flutter reads '
          'as a separator between packages. Use a rule of a different length, '
          'for example the 102-dash one the rest of the file uses.',
    );
  });
}
