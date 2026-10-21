// The Android and iOS bridges of the per-map Pigeon calls (MapHostApi.kt and
// MapHostApi.swift) rebuild by hand the method channel call each message
// replaces, with its name and the keys of its argument map, and hand it to
// the method switch of the controller. A typo in a name or a key compiles on
// both platforms and fails at run time on one of them only, so this reads the
// sources and checks the bridges against the schema, against each other and
// against the switches. It reads files from disk, so vm only.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _schemaPath = 'pigeons/messages.dart';
const _kotlinBridgePath =
    'android/src/main/java/org/maplibre/maplibregl/MapHostApi.kt';
const _swiftBridgePath = 'ios/maplibre_gl/Sources/maplibre_gl/MapHostApi.swift';
const _androidSwitchPath =
    'android/src/main/java/org/maplibre/maplibregl/MapLibreMapController.java';
const _iosSwitchPath =
    'ios/maplibre_gl/Sources/maplibre_gl/MapLibreMapController.swift';

/// The calls whose legacy arguments were not a map but one parameter of the
/// message as it is, by message, with that parameter.
const _passedAsIs = {'locationComponentSetManualLocation': 'update'};

/// The legacy calls the iOS switch has no case for: Dart rejects them on iOS
/// before sending, and the controller answers not implemented otherwise.
const _notOnIos = {
  'source#setFeatureState',
  'source#removeFeatureState',
  'source#getFeatureState',
};

final _stringLiteral = RegExp(r'"([^"\\]*)"');
final _legacyName = RegExp(r'^\w+#\w+$');
final _key = RegExp(r'^\w+$');

void main() {
  late Map<String, List<String>> parameters;
  late Map<String, _LegacyCall> kotlin;
  late Map<String, _LegacyCall> swift;

  setUpAll(() {
    parameters = _schemaParameters(_read(_schemaPath));
    kotlin = _kotlinCalls(_read(_kotlinBridgePath), parameters.keys);
    swift = _swiftCalls(_read(_swiftBridgePath), parameters.keys);
  });

  test('the schema declares the calls of a map', () {
    // Guards the parsing below: an empty schema would check nothing.
    expect(parameters, hasLength(greaterThan(70)));
  });

  test('the bridges rebuild the same call for every message', () {
    final mismatches = [
      for (final message in parameters.keys)
        if (kotlin[message].toString() != swift[message].toString())
          '$message: Kotlin ${kotlin[message]}, Swift ${swift[message]}',
    ];

    expect(mismatches, isEmpty);
  });

  test('the argument keys are the parameter names of each message', () {
    // As the schema documents, so a typo shared by both bridges shows too.
    final mismatches = <String>[];
    for (final MapEntry(key: message, value: names) in parameters.entries) {
      final call = kotlin[message]!;
      final expected = switch (_passedAsIs[message]) {
        final parameter? => '${call.method}($parameter)',
        null when names.isEmpty && call.keys == null => '${call.method}(null)',
        null => _LegacyCall(call.method, names.toSet()).toString(),
      };
      if (call.toString() != expected) {
        mismatches.add('$message: $call, expected $expected');
      }
    }

    expect(mismatches, isEmpty);
  });

  test('the Android switch has a case for every call', () {
    final cases = _switchCases(_read(_androidSwitchPath));
    final built = {for (final call in kotlin.values) call.method};

    expect(built.difference(cases), isEmpty);
  });

  test('the iOS switch has a case for every call it implements', () {
    final cases = _switchCases(_read(_iosSwitchPath));
    final built = {for (final call in swift.values) call.method};

    // The exceptions are exactly the calls iOS does not implement, so the
    // list follows when one gets implemented.
    expect(built.difference(cases), _notOnIos);
  });
}

/// One legacy call as a bridge rebuilds it.
class _LegacyCall {
  _LegacyCall(this.method, this.keys, {this.passedAsIs});

  /// The method channel method name, such as `map#update`.
  final String method;

  /// The keys of the argument map, or null for null arguments.
  final Set<String>? keys;

  /// The parameter passed as the arguments, for the calls of [_passedAsIs].
  final String? passedAsIs;

  @override
  String toString() {
    if (passedAsIs != null) return '$method($passedAsIs)';
    final keys = this.keys;
    if (keys == null) return '$method(null)';
    return '$method({${(keys.toList()..sort()).join(', ')}})';
  }
}

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path moved; update this test');
  return _withoutComments(file.readAsStringSync());
}

/// [source] without its comments, so a name or a key a comment mentions is
/// not taken for code. Only whole-line `//` comments are removed: a string
/// may hold `//`, as in a URL.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'^[ \t]*//.*$', multiLine: true), '');

/// The parameter names of each method of `MapLibreMapHostApi`, in order.
Map<String, List<String>> _schemaParameters(String schema) {
  const start = 'abstract class MapLibreMapHostApi {';
  final from = schema.indexOf(start);
  expect(from, isNot(-1), reason: 'MapLibreMapHostApi not found in the schema');
  final body = schema.substring(from, schema.indexOf('\n}', from));
  final method = RegExp(r'@asyncCallback\s+[\w<>?,\s]+?\s(\w+)\(([^)]*)\);');
  return {
    for (final match in method.allMatches(body))
      match.group(1)!: _parameterNames(match.group(2)!),
  };
}

List<String> _parameterNames(String parameters) {
  // Drops the type arguments first, whose commas are not separators.
  var flat = parameters;
  final typeArguments = RegExp('<[^<>]*>');
  while (typeArguments.hasMatch(flat)) {
    flat = flat.replaceAll(typeArguments, '');
  }
  return [
    for (final parameter in flat.split(','))
      if (parameter.trim().isNotEmpty)
        RegExp(r'(\w+)$').firstMatch(parameter.trim())!.group(1)!,
  ];
}

/// The text of each function of a class body, by name, from its declaration
/// to the next declaration of the same level. [declaration] matches every
/// such declaration, with the name of a function as its first group, and
/// also whatever else ends one, such as the end of the class.
Map<String, String> _functions(String source, RegExp declaration) {
  final matches = declaration.allMatches(source).toList();
  return {
    for (var i = 0; i < matches.length; i++)
      if (matches[i].group(1) case final name?)
        name: source.substring(
          matches[i].start,
          i + 1 < matches.length ? matches[i + 1].start : source.length,
        ),
  };
}

/// The one legacy method name of a bridge function, and its other string
/// literals that can be keys.
(String, Set<String>) _literals(String message, String function) {
  final literals = [
    for (final match in _stringLiteral.allMatches(function)) match.group(1)!,
  ];
  final names = literals.where(_legacyName.hasMatch).toSet();
  expect(names, hasLength(1), reason: '$message names one legacy method');
  return (names.single, literals.where(_key.hasMatch).toSet());
}

Map<String, _LegacyCall> _kotlinCalls(
  String source,
  Iterable<String> messages,
) {
  // Members are indented by four spaces; the class ends at column 0.
  final functions = _functions(
    source,
    RegExp(
      r'^(?:    (?:override |private )?fun (?:<\w+> )?(\w+)\(|    companion object|\S)',
      multiLine: true,
    ),
  );
  // The helpers that build the arguments shared by the layer calls.
  final helpers = {
    for (final MapEntry(key: name, value: function) in functions.entries)
      if (name.endsWith('Arguments'))
        name: {
          for (final match in _stringLiteral.allMatches(function))
            if (_key.hasMatch(match.group(1)!)) match.group(1)!,
        },
  };
  return {
    for (final message in messages)
      message: _kotlinCall(message, functions[message], helpers),
  };
}

_LegacyCall _kotlinCall(
  String message,
  String? function,
  Map<String, Set<String>> helpers,
) {
  expect(function, isNotNull, reason: '$message is missing in MapHostApi.kt');
  final (method, literalKeys) = _literals(message, function!);
  final quoted = RegExp.escape('"$method"');
  if (_passedAsIs[message] case final parameter?) {
    expect(
      function,
      matches(RegExp('$quoted,\\s*$parameter\\s*,')),
      reason: '$message passes $parameter as the arguments',
    );
    return _LegacyCall(method, null, passedAsIs: parameter);
  }
  if (RegExp('$quoted,\\s*null\\s*,').hasMatch(function)) {
    return _LegacyCall(method, null);
  }
  final keys = {
    ...literalKeys,
    for (final MapEntry(key: helper, value: helperKeys) in helpers.entries)
      if (function.contains('$helper(')) ...helperKeys,
  };
  expect(
    keys.isNotEmpty || function.contains('hashMapOf<String, Any?>()'),
    isTrue,
    reason: '$message builds its arguments in a way this test cannot read',
  );
  return _LegacyCall(method, keys);
}

Map<String, _LegacyCall> _swiftCalls(String source, Iterable<String> messages) {
  // Members are indented by four spaces; the class ends at column 0.
  final functions = _functions(
    source,
    RegExp(
      r'^(?:    (?:(?:private|fileprivate|static) )*func (\w+)\(|\S)',
      multiLine: true,
    ),
  );
  return {
    for (final message in messages)
      message: _swiftCall(message, functions[message]),
  };
}

_LegacyCall _swiftCall(String message, String? function) {
  expect(
    function,
    isNotNull,
    reason: '$message is missing in MapHostApi.swift',
  );
  final (method, keys) = _literals(message, function!);
  final quoted = RegExp.escape('"$method"');
  if (_passedAsIs[message] case final parameter?) {
    expect(
      function,
      matches(RegExp('$quoted,\\s*arguments:\\s*legacyMap\\($parameter\\)')),
      reason: '$message passes $parameter as the arguments',
    );
    return _LegacyCall(method, null, passedAsIs: parameter);
  }
  if (RegExp('send\\(\\s*$quoted,\\s*result:').hasMatch(function)) {
    return _LegacyCall(method, null);
  }
  expect(
    keys.isNotEmpty || function.contains('[:]'),
    isTrue,
    reason: '$message builds its arguments in a way this test cannot read',
  );
  return _LegacyCall(method, keys);
}

/// The legacy method names a method switch has a `case` for. A Swift case
/// may list several.
Set<String> _switchCases(String source) {
  final caseLine = RegExp(r'^\s*case\s+"');
  final cases = {
    for (final line in source.split('\n'))
      if (caseLine.hasMatch(line))
        for (final match in _stringLiteral.allMatches(line))
          if (_legacyName.hasMatch(match.group(1)!)) match.group(1)!,
  };
  expect(cases, isNotEmpty, reason: 'no method switch found');
  return cases;
}
