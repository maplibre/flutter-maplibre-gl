import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache_template.dart';
import 'package:recase/recase.dart';

import 'utils.dart';

const styleUrl =
    'https://raw.githubusercontent.com/maplibre/maplibre-style-spec/main/src/reference/v8.json';

const templates = [
  "android/src/main/java/com/mapbox/mapboxgl/LayerPropertyConverter.java",
  "ios/Classes/LayerPropertyConverter.swift",
  "lib/src/layer_expressions.dart",
  "lib/src/layer_properties.dart",
  "maplibre_gl_web/lib/src/layer_tools.dart",
  "maplibre_gl_platform_interface/lib/src/source_properties.dart",
];

Future<void> main() async {
  var styleJson = jsonDecode((await http.get(Uri.parse(styleUrl))).body);
  print('Style specification downloaded');

  final renderContext = {
    "layerTypes": [
      for (var type in layerTypes)
        {
          "type": type,
          "typePascal": ReCase(type).pascalCase,
          "typeCamel": ReCase(type).camelCase,
          "paint_properties": buildStyleProperties(styleJson, "paint_$type"),
          "layout_properties": buildStyleProperties(styleJson, "layout_$type"),
        },
    ],
    "sourceTypes": [
      for (var type in sourceTypes)
        {
          "type": type.replaceAll("_", "-"),
          "typePascal": ReCase(type).pascalCase,
          "properties": buildSourceProperties(styleJson, "source_$type"),
        },
    ],
    'expressions': buildExpressionProperties(styleJson)
  };

  // required for deduplication
  renderContext["all_layout_properties"] = <dynamic>{
    for (final type in renderContext["layerTypes"]!)
      ...type["layout_properties"].map((p) => p["value"])
  }.map((p) => {"property": p}).toList();

  for (var template in templates) {
    await render(renderContext, template);
  }
}

Future<void> render(
  Map<String, List> renderContext,
  String path,
) async {
  final pathItems = path.split("/");
  final filename = pathItems.removeLast();
  final outputPath = pathItems.join("/");

  print("Rendering $filename");
  var templateFile = await File('./code_generator/templates/$filename.template')
      .readAsString();

  var template = Template(templateFile);
  var outputFile = File('$outputPath/$filename');

  outputFile.writeAsString(template.renderString(renderContext));
}

List<Map<String, dynamic>> buildStyleProperties(
  Map<String, dynamic> styleJson,
  String key,
) {
  final Map<String, dynamic> items = styleJson[key];

  return items.entries.map((e) => buildStyleProperty(e.key, e.value)).toList();
}

Map<String, dynamic> buildStyleProperty(
  String key,
  Map<String, dynamic> value,
) {
  final camelCase = ReCase(key).camelCase;
  return <String, dynamic>{
    'value': key,
    'isVisibilityProperty': key == "visibility",
    'requiresLiteral': key == "icon-image",
    'isIosAsCamelCase': renamedIosProperties.containsKey(camelCase),
    'iosAsCamelCase': renamedIosProperties[camelCase],
    'doc': value["doc"],
    'docSplit': buildDocSplit(value).map((s) => {"part": s}).toList(),
    'valueAsCamelCase': camelCase
  };
}

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

Map<String, dynamic> buildSourceProperty(
  String key,
  Map<String, dynamic> value,
) {
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
      for (var value in values.entries) {
        result.add("  \"${value.key}\"");
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

List<String> splitIntoChunks(
  String input,
  int lineLength, {
  String prefix = "",
}) {
  final words = input.split(" ");
  final chunks = <String>[];

  String chunk = "";
  for (var word in words) {
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

List<Map<String, dynamic>> buildExpressionProperties(
  Map<String, dynamic> styleJson,
) {
  final Map<String, dynamic> items = styleJson["expression_name"]["values"];

  return items.entries
      .map((e) => <String, dynamic>{
            'value': e.key,
            'doc': e.value["doc"],
            'docSplit': buildDocSplit(e.value).map((s) => {"part": s}).toList(),
            'valueAsCamelCase':
                ReCase(renamedExpressions[e.key] ?? e.key).camelCase
          })
      .toList();
}