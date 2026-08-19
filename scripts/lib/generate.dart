// Code generation entry point for the MapLibre Flutter workspace.
//
// This script reads the canonical style definition (style.json) and produces
// strongly-typed Dart (and some platform specific Java/Swift) sources that
// expose layer & source properties plus expression helpers.
//
// Key goals:
//  - Keep hand‑written logic small; most surface area is generated.
//  - Ensure deterministic output (stable ordering helps minimal diffs).
//  - Generated Dart files are batch‑formatted at the end using `dart format`
//    so that a subsequent CI `melos format-all` step produces no diffs.
//
// Notes:
//  - Do NOT edit the generated files manually; instead adjust templates or
//    this generator.
//  - The generator intentionally avoids adding a per‑file language version
//    pragma to prevent part <-> library mismatches (see earlier CI issue).
//  - If the style specification evolves, update templates & mapping tables
//    inside conversions.dart.
//  - Run via:  melos run generate
//
import 'dart:io';
import 'dart:convert';

import 'package:mustache_template/mustache_template.dart';
import 'package:recase/recase.dart';

import 'conversions.dart';

Future<void> main() async {
  /// We assume the current working directory for this script is the scripts/
  /// package root (melos exec enforces that). style.json lives under input/.
  final currentPath = Directory.current.path;
  final styleFilePath = '$currentPath/input/style.json';
  final styleJson = jsonDecode(await File(styleFilePath).readAsString());

  // style.json is a verbatim copy of the upstream MapLibre style spec, so it
  // also describes properties the pinned native SDKs do not implement yet.
  // The Java/Swift templates emit a native call per property, therefore each
  // native template only receives the properties its SDK supports (per the
  // spec's own sdk-support metadata). The versions are parsed from the build
  // files so upgrading the SDKs automatically unlocks newly supported
  // properties on the next generate run.
  final androidVersion = readAndroidSdkVersion();
  final iosVersion = readIosSdkVersion();
  print('Native SDK versions: android $androidVersion, ios $iosVersion');

  /// Layer types in the order we want to render them. Order matters for
  /// deterministic output & smaller diffs.
  final layerTypes = [
    "symbol",
    "circle",
    "line",
    "fill",
    "fill-extrusion",
    "raster",
    "hillshade",
    "heatmap",
    "color-relief",
    "background",
  ];

  /// Source types. The template will convert snake_case to
  /// the appropriate casing for class names and enum-like strings.
  final sourceTypes = [
    "vector",
    "raster",
    "raster_dem",
    "geojson",
    "video",
    "image",
  ];

  /// Build the mustache rendering context consumed by each template.
  /// Most heavy lifting (doc splitting, type inference) happens in helper
  /// functions below for clarity & reuse.
  final renderContext = {
    "layerTypes": [
      for (final type in layerTypes)
        {
          "type": type,
          "typePascal": ReCase(type).pascalCase,
          "typeCamel": ReCase(type).camelCase,
          "paint_properties": buildStyleProperties(styleJson, "paint_$type"),
          "layout_properties": buildStyleProperties(styleJson, "layout_$type"),
          "paint_properties_android": buildStyleProperties(
            styleJson,
            "paint_$type",
            platform: "android",
            platformVersion: androidVersion,
          ),
          "layout_properties_android": buildStyleProperties(
            styleJson,
            "layout_$type",
            platform: "android",
            platformVersion: androidVersion,
          ),
          "paint_properties_ios": buildStyleProperties(
            styleJson,
            "paint_$type",
            platform: "ios",
            platformVersion: iosVersion,
          ),
          "layout_properties_ios": buildStyleProperties(
            styleJson,
            "layout_$type",
            platform: "ios",
            platformVersion: iosVersion,
          ),
        },
    ],
    "sourceTypes": [
      for (final type in sourceTypes)
        {
          "type": type.replaceAll("_", "-"),
          "typePascal": ReCase(type).pascalCase,
          "properties": buildSourceProperties(styleJson, "source_$type"),
        },
    ],
    'expressions': buildExpressionProperties(styleJson),
  };

  // required for deduplication
  // Collect a set of all layout property names across layer types to enable
  // template logic for shared helpers / deduplication.
  renderContext["all_layout_properties"] =
      <dynamic>{
        for (final type in renderContext["layerTypes"]!)
          ...type["layout_properties"].map((p) => p["value"]),
      }.map((p) => {"property": p}).toList();

  // Ordered list of templates we render. If you add a new feature, append
  // here to keep existing diff noise minimal.
  const templates = [
    "maplibre_gl/android/src/main/java/org/maplibre/maplibregl/LayerPropertyConverter.java",
    "maplibre_gl/ios/maplibre_gl/Sources/maplibre_gl/LayerPropertyConverter.swift",
    "maplibre_gl/lib/src/layer_expressions.dart",
    "maplibre_gl/lib/src/layer_properties.dart",
    "maplibre_gl_web/lib/src/layer_tools.dart",
    "maplibre_gl_platform_interface/lib/src/source_properties.dart",
  ];

  final generatedDartFiles = <String>[];
  for (final template in templates) {
    final path = await render(renderContext, template);
    if (path.endsWith('.dart')) {
      generatedDartFiles.add(path);
    }
  }

  // Auto-format only the Dart files we just generated so that a subsequent
  // CI `melos format-all` step does not introduce extra diffs.
  if (generatedDartFiles.isNotEmpty) {
    final result = await Process.run(
      'dart',
      ['format', ...generatedDartFiles],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      stderr.writeln('Warning: dart format failed: ${result.stderr}');
    }
  }
}

/// Render a single template file.
/// [path] is the relative workspace path to the output (and indirectly the
/// template at scripts/templates/$filename.template).
/// Returns the absolute path of the written file.
Future<String> render(
  Map<String, List> renderContext,
  String path,
) async {
  final currentParentPath = Directory.current.parent.path;

  final pathItems = path.split("/");
  final filename = pathItems.removeLast();
  final outputPath = '$currentParentPath/${pathItems.join("/")}';

  print("Rendering $filename");
  final templateFile =
      await File(
        '$currentParentPath/scripts/templates/$filename.template',
      ).readAsString();

  final template = Template(templateFile);
  final outputFile = File('$outputPath/$filename');

  final rendered = template.renderString(renderContext);
  await outputFile.writeAsString(rendered);
  return outputFile.path;
}

/// Read the MapLibre Android SDK version pinned in the plugin build.gradle.
String readAndroidSdkVersion() {
  final gradle =
      File(
        '${Directory.current.parent.path}/maplibre_gl/android/build.gradle',
      ).readAsStringSync();
  final match = RegExp(
    r"org\.maplibre\.gl:android-sdk[\w-]*:(\d+(?:\.\d+)*)",
  ).firstMatch(gradle);
  if (match == null) {
    throw StateError(
      'Could not find the MapLibre Android SDK version in build.gradle',
    );
  }
  return match.group(1)!;
}

/// Read the MapLibre iOS SDK version pinned in the plugin podspec.
String readIosSdkVersion() {
  final podspec =
      File(
        '${Directory.current.parent.path}/maplibre_gl/ios/maplibre_gl.podspec',
      ).readAsStringSync();
  final match = RegExp(
    r"s\.dependency\s+'MapLibre',\s+'(\d+(?:\.\d+)*)'",
  ).firstMatch(podspec);
  if (match == null) {
    throw StateError(
      'Could not find the MapLibre iOS SDK version in maplibre_gl.podspec',
    );
  }
  return match.group(1)!;
}

/// Compare two dotted version strings ("13.4.1"). Returns a negative value
/// if [a] < [b], zero if equal, positive if [a] > [b].
int compareVersions(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

/// In sdk-support metadata a version number means "supported since", while
/// an issue URL or "wontfix" means "not implemented on this platform".
bool isImplemented(Object? sdkSupportValue) =>
    RegExp(r'^\d+(\.\d+)*$').hasMatch('$sdkSupportValue');

/// Platforms the spec credits with a property their SDK does not expose,
/// keyed by the property name in the spec. Only the generated docs are
/// corrected, so this is for source properties, which every platform shares
/// one class for; a layer property would also have to be gated out of the
/// native converters.
///
/// `volatile` records ios since 5.10.0, which is a Mapbox iOS version. The
/// MapLibre iOS SDK has no equivalent of Android's `Source.setVolatile`, so an
/// app that trusts the doc gets tiles cached to disk with nothing to warn it.
const unsupportedPlatformOverrides = {
  "volatile": {"ios"},
};

/// Whether the native SDK at [platformVersion] supports a property, based on
/// the spec's sdk-support metadata.
/// Properties without sdk-support info are treated as supported: they predate
/// the metadata, and if that assumption is ever wrong the generated native
/// code fails to compile loudly instead of silently dropping the property.
bool isSupportedOnPlatform(
  Map<String, dynamic> propertySpec,
  String platform,
  String platformVersion,
) {
  final Map<String, dynamic>? support =
      propertySpec["sdk-support"]?["basic functionality"];
  if (support == null) return true;
  final since = support[platform];
  if (since == null || !isImplemented(since)) return false;
  return compareVersions(platformVersion, '$since') >= 0;
}

/// Build the (paint/layout) style properties list for a given style.json key.
/// When [platform] is given, properties the native SDK at [platformVersion]
/// does not support are omitted.
List<Map<String, dynamic>> buildStyleProperties(
  Map<String, dynamic> styleJson,
  String key, {
  String? platform,
  String? platformVersion,
}) {
  final Map<String, dynamic> items = styleJson[key] ?? <String, dynamic>{};

  final properties =
      items.entries
          .where(
            (e) =>
                platform == null ||
                isSupportedOnPlatform(e.value, platform, platformVersion!),
          )
          .map((e) => buildStyleProperty(e.key, e.value))
          .toList();

  // Only the paint branch of the native templates wraps a single value into the
  // array the SDK expects. No layout property is array-typed in the spec today,
  // so rather than carrying a second copy of that logic, stop here if one ever
  // appears: the wrap has to be added to the layout branch first, or the value
  // would reach the native SDK unwrapped and be rejected at runtime.
  if (key.startsWith("layout_")) {
    for (final property in properties) {
      if (property['isColorArrayProperty'] == true ||
          property['isNumberArrayProperty'] == true) {
        throw StateError(
          'The layout property $key.${property['value']} is array-typed, which '
          'the Java and Swift layout templates do not wrap yet. Add the '
          'colorArray/numberArray handling to the layout section of '
          'scripts/templates/LayerPropertyConverter.{java,swift}.template.',
        );
      }
    }
  }

  return properties;
}

/// Translate a single raw style property spec into a template-ready map.
Map<String, dynamic> buildStyleProperty(
  String key,
  Map<String, dynamic> value,
) {
  final typeDart = dartTypeMappingTable[value["type"]];
  final nestedTypeDart =
      dartTypeMappingTable[value["value"]] ??
      dartTypeMappingTable[value["value"]?["type"]];
  final camelCase = ReCase(key).camelCase;

  // Multidirectional hillshading turned some properties into array types
  // (MapLibre Native 6.24.0 / Android 13.0.0), which the spec marks with the
  // colorArray and numberArray types. A single value coming from the Dart API
  // has to be wrapped in an array before it reaches the native SDK.
  final isColorArrayProperty = value["type"] == "colorArray";
  final isNumberArrayProperty = value["type"] == "numberArray";
  var iosExpression = 'expression';
  if (isColorArrayProperty) {
    iosExpression = 'wrapColorAsArray(expression)';
  } else if (isNumberArrayProperty) {
    iosExpression = 'wrapValueAsArray(expression)';
  }

  return <String, dynamic>{
    'value': key,
    'isFloatArrayProperty': typeDart == "List" && nestedTypeDart == "double",
    'isColorArrayProperty': isColorArrayProperty,
    'isNumberArrayProperty': isNumberArrayProperty,
    'isVisibilityProperty': key == "visibility",
    'isPatternProperty': key.endsWith("-pattern"),
    'requiresLiteral': key == "icon-image" || key == "text-field",
    'isFontProperty': key == "text-font",
    'isIosAsCamelCase': renamedIosProperties.containsKey(camelCase),
    'iosAsCamelCase': renamedIosProperties[camelCase],
    'iosExpression': iosExpression,
    'doc': value["doc"],
    'docSplit':
        buildDocSplit(value, name: key).map((s) => {"part": s}).toList(),
    'valueAsCamelCase': camelCase,
  };
}

/// Build the list of source properties (excluding generic wildcard entries).
List<Map<String, dynamic>> buildSourceProperties(
  Map<String, dynamic> styleJson,
  String key,
) {
  final Map<String, dynamic> items = styleJson[key];

  return items.entries
      .where((e) => e.key != "*" && e.key != "type")
      .map((e) => buildSourceProperty(e.key, e.value))
      .toList();
}

/// Source properties that are only valid under another property's setting
/// (the raster-dem custom-encoding factors require `encoding: "custom"`).
/// Their spec defaults must not become Dart constructor defaults: MapLibre
/// GL JS validates the source JSON and rejects these keys when the encoding
/// does not allow them, so they may only be serialized when set explicitly.
const conditionalSourceProperties = {
  "redFactor",
  "greenFactor",
  "blueFactor",
  "baseShift",
};

/// Translate one source property spec to a template map, including default
/// value normalization (prefixing const for literal lists, quoting strings).
Map<String, dynamic> buildSourceProperty(
  String key,
  Map<String, dynamic> value,
) {
  final camelCase = ReCase(key).camelCase;
  final typeDart = dartTypeMappingTable[value["type"]];
  final typeSwift = swiftTypeMappingTable[value["type"]];
  final nestedTypeDart =
      dartTypeMappingTable[value["value"]] ??
      dartTypeMappingTable[value["value"]?["type"]];
  final nestedTypeSwift =
      swiftTypeMappingTable[value["value"]] ??
      swiftTypeMappingTable[value["value"]?["type"]];

  var defaultValue =
      conditionalSourceProperties.contains(key) ? null : value["default"];
  if (defaultValue is List) {
    defaultValue = "const$defaultValue";
  } else if (defaultValue is String) {
    defaultValue = '"$defaultValue"';
  }

  return <String, dynamic>{
    'value': key,
    'doc': value["doc"],
    'default': defaultValue,
    'hasDefault': defaultValue != null,
    'type': nestedTypeDart == null ? typeDart : "$typeDart<$nestedTypeDart>",
    'typeSwift':
        nestedTypeSwift == null ? typeSwift : "$typeSwift<$nestedTypeSwift>",
    'docSplit':
        buildDocSplit(value, name: key).map((s) => {"part": s}).toList(),
    'valueAsCamelCase': camelCase,
  };
}

/// Produce a wrapped documentation block (array of lines) including
/// type/default/constraints plus enumerated option docs. [name] is the
/// property name in the spec, used to look up [unsupportedPlatformOverrides].
List<String> buildDocSplit(Map<String, dynamic> item, {String? name}) {
  final defaultValue = item["default"];
  final maxValue = item["maximum"];
  final minValue = item["minimum"];
  final type = item["type"];
  final Map<dynamic, dynamic>? sdkSupport = item["sdk-support"];

  final Map<String, dynamic>? values = item["values"];
  final result = splitIntoChunks(item["doc"]!, 70);
  if (type != null) {
    result.add("");
    result.add("Type: $type");
    if (defaultValue != null) result.add("  default: $defaultValue");
    if (minValue != null) result.add("  minimum: $minValue");
    if (maxValue != null) result.add("  maximum: $maxValue");
    if (values != null) {
      result.add("Options:");
      for (final value in values.entries) {
        result.add('  "${value.key}"');
        result.addAll(
          splitIntoChunks("${value.value["doc"]}", 70, prefix: "     "),
        );
      }
    }
  }
  final support = [
    ...buildSupportLines("basic functionality", sdkSupport, name),
    ...buildSupportLines("data-driven styling", sdkSupport, name),
  ];
  if (support.isNotEmpty) {
    result.add("");
    result.add("Sdk Support:");
    result.addAll(support);
  }

  return result;
}

/// The doc line for one sdk-support entry, naming the platforms that implement
/// it and the ones that do not. Both belong in the docs: a platform the spec
/// records with an issue URL instead of a version accepts the property and
/// silently ignores it, which is worth saying out loud.
List<String> buildSupportLines(
  String kind,
  Map<dynamic, dynamic>? sdkSupport, [
  String? name,
]) {
  final Map<String, dynamic>? support = sdkSupport?[kind];
  if (support == null || support.isEmpty) return [];

  final overridden = unsupportedPlatformOverrides[name] ?? const <String>{};
  bool implementsIt(String platform) =>
      isImplemented(support[platform]) && !overridden.contains(platform);

  final implemented = support.keys.where(implementsIt);
  final missing = support.keys.where((p) => !implementsIt(p));
  if (implemented.isEmpty) {
    return ["  $kind on no platform yet"];
  }
  final not = missing.isEmpty ? "" : " (not on ${missing.join(", ")})";
  return ["  $kind with ${implemented.join(", ")}$not"];
}

/// Simple greedy word-wrapping utility used for docs.
List<String> splitIntoChunks(
  String input,
  int lineLength, {
  String prefix = "",
}) {
  final words = input.split(" ");
  final chunks = <String>[];

  var chunk = "";
  for (final word in words) {
    final nextChunk = chunk.isEmpty ? prefix + word : "$chunk $word";
    if (nextChunk.length > lineLength || chunk.endsWith("\n")) {
      chunks.add(chunk.replaceAll("\n", ""));
      chunk = prefix + word;
    } else {
      chunk = nextChunk;
    }
  }
  chunks.add(chunk);

  return chunks;
}

/// Build expression metadata (renaming reserved or symbolic operators to
/// valid method-like identifiers for Dart code generation).
List<Map<String, dynamic>> buildExpressionProperties(
  Map<String, dynamic> styleJson,
) {
  final Map<String, dynamic> items = styleJson["expression_name"]["values"];

  final renamed = {
    "var": "varExpression",
    "in": "inExpression",
    "case": "caseExpression",
    "to-string": "toStringExpression",
    "+": "plus",
    "*": "multiply",
    "-": "minus",
    "%": "modulo",
    ">": "larger",
    ">=": "largerOrEqual",
    "<": "smaller",
    "<=": "smallerOrEqual",
    "!=": "notEqual",
    "==": "equal",
    "/": "divide",
    "^": "power",
    "!": "not",
  };

  /// Names that shipped for an operator before it was named after what it
  /// actually does. Kept as deprecated aliases so existing code still compiles.
  const deprecated = {
    "modulo": ("precent", '"%" is the remainder operator'),
    "power": ("xor", '"^" raises the first input to the power of the second'),
  };

  return items.entries.map((e) {
    final name = ReCase(renamed[e.key] ?? e.key).camelCase;
    final alias = deprecated[name];
    return <String, dynamic>{
      'value': e.key,
      'doc': e.value["doc"],
      'docSplit':
          buildDocSplit(e.value, name: e.key).map((s) => {"part": s}).toList(),
      'valueAsCamelCase': name,
      'deprecatedName': alias?.$1,
      'deprecationReason': alias?.$2,
    };
  }).toList();
}
