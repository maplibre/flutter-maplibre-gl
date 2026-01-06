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
  ];

  /// Source types. The template will convert snake_case to
  /// the appropriate casing for class names and enum-like strings.
  final sourceTypes = [
    "vector",
    "raster",
    "raster_dem",
    "geojson",
    "video",
    "image"
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
    'expressions': buildExpressionProperties(styleJson)
  };

  // required for deduplication
  // Collect a set of all layout property names across layer types to enable
  // template logic for shared helpers / deduplication.
  renderContext["all_layout_properties"] = <dynamic>{
    for (final type in renderContext["layerTypes"]!)
      ...type["layout_properties"].map((p) => p["value"])
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
      await File('$currentParentPath/scripts/templates/$filename.template')
          .readAsString();

  final template = Template(templateFile);
  final outputFile = File('$outputPath/$filename');

  final rendered = template.renderString(renderContext);
  await outputFile.writeAsString(rendered);
  return outputFile.path;
}

/// Build the (paint/layout) style properties list for a given style.json key.
List<Map<String, dynamic>> buildStyleProperties(
    Map<String, dynamic> styleJson, String key) {
  final Map<String, dynamic> items = styleJson[key];

  return items.entries.map((e) => buildStyleProperty(e.key, e.value)).toList();
}

/// Translate a single raw style property spec into a template-ready map.
Map<String, dynamic> buildStyleProperty(
    String key, Map<String, dynamic> value) {
  final typeDart = dartTypeMappingTable[value["type"]];
  final nestedTypeDart = dartTypeMappingTable[value["value"]] ??
      dartTypeMappingTable[value["value"]?["type"]];
  final camelCase = ReCase(key).camelCase;

  return <String, dynamic>{
    'value': key,
    'isFloatArrayProperty': typeDart == "List" && nestedTypeDart == "double",
    'isVisibilityProperty': key == "visibility",
    'isPatternProperty': key.endsWith("-pattern"),
    'requiresLiteral': key == "icon-image",
    'isIosAsCamelCase': renamedIosProperties.containsKey(camelCase),
    'iosAsCamelCase': renamedIosProperties[camelCase],
    'doc': value["doc"],
    'docSplit': buildDocSplit(value).map((s) => {"part": s}).toList(),
    'valueAsCamelCase': camelCase
  };
}

/// Build the list of source properties (excluding generic wildcard entries).
List<Map<String, dynamic>> buildSourceProperties(
    Map<String, dynamic> styleJson, String key) {
  final Map<String, dynamic> items = styleJson[key];

  return items.entries
      .where((e) => e.key != "*" && e.key != "type")
      .map((e) => buildSourceProperty(e.key, e.value))
      .toList();
}

/// Translate one source property spec to a template map, including default
/// value normalization (prefixing const for literal lists, quoting strings).
Map<String, dynamic> buildSourceProperty(
    String key, Map<String, dynamic> value) {
  final camelCase = ReCase(key).camelCase;
  final typeDart = dartTypeMappingTable[value["type"]];
  final typeSwift = swiftTypeMappingTable[value["type"]];
  final nestedTypeDart = dartTypeMappingTable[value["value"]] ??
      dartTypeMappingTable[value["value"]?["type"]];
  final nestedTypeSwift = swiftTypeMappingTable[value["value"]] ??
      swiftTypeMappingTable[value["value"]?["type"]];

  var defaultValue = value["default"];
  if (defaultValue is List) {
    defaultValue = "const$defaultValue";
  } else if (defaultValue is String) {
    defaultValue = '"$defaultValue"';
  }

  return <String, dynamic>{
    'value': key,
    'doc': value["doc"],
    'default': defaultValue,
    'hasDefault': value["default"] != null,
    'type': nestedTypeDart == null ? typeDart : "$typeDart<$nestedTypeDart>",
    'typeSwift':
        nestedTypeSwift == null ? typeSwift : "$typeSwift<$nestedTypeSwift>",
    'docSplit': buildDocSplit(value).map((s) => {"part": s}).toList(),
    'valueAsCamelCase': camelCase
  };
}

/// Produce a wrapped documentation block (array of lines) including
/// type/default/constraints plus enumerated option docs.
List<String> buildDocSplit(Map<String, dynamic> item) {
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
            splitIntoChunks("${value.value["doc"]}", 70, prefix: "     "));
      }
    }
  }
  if (sdkSupport != null) {
    final Map<String, dynamic>? basic = sdkSupport["basic functionality"];
    final Map<String, dynamic>? dataDriven = sdkSupport["data-driven styling"];

    result.add("");
    result.add("Sdk Support:");
    if (basic != null && basic.isNotEmpty) {
      result.add("  basic functionality with ${basic.keys.join(", ")}");
    }
    if (dataDriven != null && dataDriven.isNotEmpty) {
      result.add("  data-driven styling with ${dataDriven.keys.join(", ")}");
    }
  }

  return result;
}

/// Simple greedy word-wrapping utility used for docs.
List<String> splitIntoChunks(String input, int lineLength,
    {String prefix = ""}) {
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
    Map<String, dynamic> styleJson) {
  final Map<String, dynamic> items = styleJson["expression_name"]["values"];

  final renamed = {
    "var": "varExpression",
    "in": "inExpression",
    "case": "caseExpression",
    "to-string": "toStringExpression",
    "+": "plus",
    "*": "multiply",
    "-": "minus",
    "%": "precent",
    ">": "larger",
    ">=": "largerOrEqual",
    "<": "smaller",
    "<=": "smallerOrEqual",
    "!=": "notEqual",
    "==": "equal",
    "/": "divide",
    "^": "xor",
    "!": "not",
  };

  return items.entries
      .map((e) => <String, dynamic>{
            'value': e.key,
            'doc': e.value["doc"],
            'docSplit': buildDocSplit(e.value).map((s) => {"part": s}).toList(),
            'valueAsCamelCase': ReCase(renamed[e.key] ?? e.key).camelCase
          })
      .toList();
}
