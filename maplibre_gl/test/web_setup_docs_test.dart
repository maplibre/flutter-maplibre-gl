// Reads documentation files from disk, so it cannot run in a browser, where
// `melos run test:web` also executes this package's tests.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The plugin loads maplibre-gl-js itself and pins the version in code
/// (`kMapLibreJsVersion` in `maplibre_gl_web`), so the documentation must not
/// name one. The old `<script src="https://unpkg.com/maplibre-gl@...">` tags
/// are exactly what someone reintroduces by copying an older README, and a
/// manually pinned copy silently overrides the version the plugin is tested
/// against, which is why their absence is asserted here.
void main() {
  // The CDN tag form. pmtiles@x.y.z is a different library and stays allowed.
  final cdnPin = RegExp('maplibre-gl@');
  // Prose naming a full maplibre-gl-js version, e.g. "MapLibre GL JS 5.24.0".
  final proseVersion = RegExp(r'\d+\.\d+\.\d+');
  final glJsMention = RegExp('maplibre[- ]gl[- ]js', caseSensitive: false);

  List<File> filesUnderTest() {
    final files = <File>[
      File('../README.md'),
      File('../maplibre_gl_example/web/index.html'),
    ];
    final websiteDocs = Directory('../website/docs');
    expect(
      websiteDocs.existsSync(),
      isTrue,
      reason: 'website/docs moved; update this test to follow it',
    );
    files.addAll(
      websiteDocs
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md')),
    );
    return files;
  }

  test('no doc shows the CDN tags or names a maplibre-gl-js version', () {
    final offenders = <String>[];

    for (final file in filesUnderTest()) {
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (cdnPin.hasMatch(line) ||
            (glJsMention.hasMatch(line) && proseVersion.hasMatch(line))) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These lines pin a maplibre-gl-js version. The plugin loads the '
          'library itself and the version lives in kMapLibreJsVersion '
          '(maplibre_gl_web/lib/src/js_loader.dart); the docs must not name '
          'one:\n${offenders.join('\n')}',
    );
  });
}
