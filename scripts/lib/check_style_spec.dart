// Verifies that input/style.json is an exact copy of the upstream MapLibre
// style specification pinned in input/style_spec_version.txt, and reports
// what a newer upstream release would bring to each platform.
//
// The spec is downloaded from the published npm package
// @maplibre/maplibre-gl-style-spec (src/reference/v8.json), which is the
// canonical source the MapLibre SDKs are generated from.
//
// Usage (from the scripts/ package root):
//   dart run lib/check_style_spec.dart            # fail if style.json drifted
//   dart run lib/check_style_spec.dart --latest   # also diff against the
//                                                 # latest upstream release
//   dart run lib/check_style_spec.dart --update           # re-pin to latest
//   dart run lib/check_style_spec.dart --update=26.2.1    # pin to a version
//
// After --update, re-run the generator: melos run generate
import 'dart:convert';
import 'dart:io';

import 'generate.dart'
    show isSupportedOnPlatform, readAndroidSdkVersion, readIosSdkVersion;

const _registryUrl =
    'https://registry.npmjs.org/@maplibre/maplibre-gl-style-spec/latest';

String _specUrl(String version) =>
    'https://cdn.jsdelivr.net/npm/@maplibre/maplibre-gl-style-spec@$version/src/reference/v8.json';

/// The style.json sections the generator consumes, in reporting order.
const _generatorSections = [
  'paint_',
  'layout_',
  'source_',
  'expression_name',
];

Future<void> main(List<String> args) async {
  final latest = args.contains('--latest');
  final updateArgs = args.where((a) => a.startsWith('--update'));
  final updateArg = updateArgs.isEmpty ? null : updateArgs.first;

  final inputDir = '${Directory.current.path}/input';
  final styleFile = File('$inputDir/style.json');
  final versionFile = File('$inputDir/style_spec_version.txt');

  final pinnedVersion = (await versionFile.readAsString()).trim();

  if (updateArg != null) {
    final requested =
        updateArg.contains('=')
            ? updateArg.split('=').last
            : await _fetchLatestVersion();
    final spec = await _fetchString(_specUrl(requested));
    // Validate before overwriting anything.
    jsonDecode(spec);
    await styleFile.writeAsString(spec);
    await versionFile.writeAsString('$requested\n');
    print(
      'style.json updated to @maplibre/maplibre-gl-style-spec@$requested '
      '(was $pinnedVersion).',
    );
    print('Re-run the generator now: melos run generate');
    return;
  }

  // 1. Alignment check: style.json must be byte-identical to the pinned
  //    upstream release, so any hand edit or partial update is caught.
  // Line endings are normalized so a Windows checkout (core.autocrlf) does not
  // read as drift.
  final local = (await styleFile.readAsString()).replaceAll('\r\n', '\n');
  final upstream = await _fetchString(_specUrl(pinnedVersion));
  if (local == upstream) {
    print(
      'OK: input/style.json matches '
      '@maplibre/maplibre-gl-style-spec@$pinnedVersion.',
    );
  } else {
    stderr.writeln(
      'FAIL: input/style.json does not match the pinned upstream spec '
      '@maplibre/maplibre-gl-style-spec@$pinnedVersion.\n'
      'Never edit style.json by hand. To re-align it, run:\n'
      '  dart run lib/check_style_spec.dart --update=$pinnedVersion\n'
      'or bump the pin with --update / --update=<version>.',
    );
    exitCode = 1;
    if (!latest) return;
  }

  if (!latest) return;

  // 2. Drift report against the latest upstream release: what a spec bump
  //    would add, and which platforms could use it today.
  final latestVersion = await _fetchLatestVersion();
  if (latestVersion == pinnedVersion) {
    print('Already pinned to the latest upstream release ($latestVersion).');
    return;
  }

  print(
    '\nNewer upstream release available: $latestVersion '
    '(pinned: $pinnedVersion). Diff of generator-relevant sections:',
  );
  final Map<String, dynamic> pinnedSpec = jsonDecode(upstream);
  final Map<String, dynamic> latestSpec = jsonDecode(
    await _fetchString(_specUrl(latestVersion)),
  );

  final androidVersion = readAndroidSdkVersion();
  final iosVersion = readIosSdkVersion();

  var changes = 0;
  for (final section in {...pinnedSpec.keys, ...latestSpec.keys}) {
    if (!_generatorSections.any(section.startsWith)) continue;
    final oldProps = _propertyMap(pinnedSpec[section]);
    final newProps = _propertyMap(latestSpec[section]);

    for (final name in newProps.keys.where((k) => !oldProps.containsKey(k))) {
      final support = [
        if (isSupportedOnPlatform(newProps[name]!, 'android', androidVersion))
          'android',
        if (isSupportedOnPlatform(newProps[name]!, 'ios', iosVersion)) 'ios',
        'web',
      ];
      print('  + $section.$name (native today: ${support.join(", ")})');
      changes++;
    }
    for (final name in oldProps.keys.where((k) => !newProps.containsKey(k))) {
      print('  - $section.$name (removed upstream)');
      changes++;
    }
  }
  if (changes == 0) {
    print('  No property-level changes in the sections the generator uses.');
  }
  print(
    '\nTo adopt it: dart run lib/check_style_spec.dart --update '
    '&& melos run generate',
  );
}

/// The properties of a spec section; expression_name nests them in "values".
Map<String, Map<String, dynamic>> _propertyMap(dynamic section) {
  if (section is! Map<String, dynamic>) return {};
  final Map<String, dynamic> entries = section['values'] ?? section;
  return {
    for (final e in entries.entries)
      if (e.value is Map<String, dynamic>) e.key: e.value,
  };
}

Future<String> _fetchLatestVersion() async {
  final body = await _fetchString(_registryUrl);
  return jsonDecode(body)['version'] as String;
}

Future<String> _fetchString(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('GET $url returned ${response.statusCode}');
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}
