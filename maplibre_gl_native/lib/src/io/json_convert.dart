import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

/// Converts a plain Dart JSON-like value ([Map]/[List]/[num]/[String]/[bool]/
/// null) into the owned [mln.JsonValue] tree used by the Dart bindings.
mln.JsonValue jsonValueFromDart(Object? value) {
  return switch (value) {
    null => const mln.JsonNull(),
    final bool v => mln.JsonBool(v),
    final int v => mln.JsonInt(v),
    final double v => mln.JsonDouble(v),
    final String v => mln.JsonString(v),
    final List<Object?> v => mln.JsonArray(v.map(jsonValueFromDart).toList()),
    final Map<Object?, Object?> v => mln.JsonObject([
      for (final entry in v.entries)
        mln.JsonMember(entry.key! as String, jsonValueFromDart(entry.value)),
    ]),
    _ => throw ArgumentError.value(
      value,
      'value',
      'unsupported JSON value of type ${value.runtimeType}',
    ),
  };
}

/// Converts an owned [mln.JsonValue] tree back into plain Dart JSON values.
Object? jsonValueToDart(mln.JsonValue value) {
  return switch (value) {
    mln.JsonNull() => null,
    mln.JsonBool(:final value) => value,
    mln.JsonInt(:final value) => value,
    mln.JsonUInt(:final value) => value,
    mln.JsonDouble(:final value) => value,
    mln.JsonString(:final value) => value,
    mln.JsonArray(:final values) => values.map(jsonValueToDart).toList(),
    mln.JsonObject(:final members) => <String, Object?>{
      for (final member in members) member.key: jsonValueToDart(member.value),
    },
  };
}
