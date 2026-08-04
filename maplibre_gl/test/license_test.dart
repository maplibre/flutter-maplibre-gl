// Reads the LICENSE file from disk, so it cannot run in a browser, where
// `melos run test:web` also executes this package's tests.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter's license collector concatenates every package's LICENSE into the
/// app's NOTICES bundle, separating them with a line of exactly 80 dashes. At
/// runtime it splits on that line and reads each block's leading lines, up to
/// the first blank line, as the names shown on the Licenses screen.
///
/// This file bundles several third-party notices, and it uses that separator on
/// purpose so each one gets its own titled entry, the same way the first-party
/// plugins in flutter/packages do. That only works while every separator is
/// followed by a name and a blank line: without the name the entry is titled
/// with the empty string, which is how #895 showed up as an untitled first row
/// on every app's Licenses screen.
///
/// None of this is visible when reading the file, so it is asserted here.
void main() {
  const separator =
      '--------------------------------------------------------------------------------';

  late List<String> lines;

  setUpAll(() {
    final license = File('LICENSE');
    expect(
      license.existsSync(),
      isTrue,
      reason: 'LICENSE is missing from the published package',
    );
    lines = license.readAsLinesSync();
  });

  test('every license separator is followed by a name and a blank line', () {
    final problems = <String>[];

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimRight() != separator) continue;

      final name = i + 1 < lines.length ? lines[i + 1].trim() : '';
      final blank = i + 2 < lines.length ? lines[i + 2].trim() : '';

      if (name.isEmpty) {
        problems.add(
          'line ${i + 1}: separator is not followed by a name, so this notice '
          'would appear untitled on the Licenses screen',
        );
      } else if (RegExp(r'^-+$').hasMatch(name)) {
        problems.add(
          'line ${i + 2}: expected a name after the separator, found another rule',
        );
      }
      if (blank.isNotEmpty) {
        problems.add(
          'line ${i + 3}: expected a blank line between the name and the '
          'license text, found "${blank.length > 40 ? '${blank.substring(0, 40)}...' : blank}"',
        );
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the third-party notices we bundle are each named', () {
    final names = <String>[];
    for (var i = 0; i + 1 < lines.length; i++) {
      if (lines[i].trimRight() == separator) {
        names.add(lines[i + 1].trim());
      }
    }

    expect(names, [
      'flutter-mapbox-gl',
      'maplibre-gl-native',
      'maplibre-gl-js',
      'mapbox-gl-js',
      'glfx.js',
      'd3-color',
    ]);
  });

  test('no rule of a different length is mistaken for a separator', () {
    // A rule that is nearly 80 dashes is a trap: it reads like a separator but
    // does not split, so its notice silently ends up inside the previous entry.
    final nearMisses = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.length < 70 || line.isEmpty) continue;
      if (!RegExp(r'^-+$').hasMatch(line)) continue;
      if (line != separator) nearMisses.add(i + 1);
    }

    expect(
      nearMisses,
      isEmpty,
      reason:
          'line(s) $nearMisses are long dash rules that are not exactly 80 '
          'dashes, so Flutter will not treat them as separators. Use exactly 80 '
          'followed by a name, or make the rule clearly shorter.',
    );
  });
}
