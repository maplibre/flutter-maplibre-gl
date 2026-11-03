part of '../maplibre_gl.dart';

/// Checks GeoJSON data and writes it as JSON text in a single pass, with its
/// feature ids as a [_FeatureIds] says.
///
/// It is the fast path of the common case: it accepts only what
/// [geoJsonError] accepts and writes what `jsonEncode` writes. On anything
/// else, an error included, it gives up, and the caller runs [geoJsonError]
/// and `jsonEncode` for the exact answer.
class _GeoJsonWriter {
  _GeoJsonWriter._(this._ids, {required bool write})
    : _writing = write,
      _bytes = Uint8List(write ? 1024 : 0);

  /// [data] as JSON text with its ids as [ids] says, or null when it takes
  /// the slow path. [data] is a FeatureCollection, a Feature or a geometry,
  /// and only a Feature with [feature].
  static String? encode(
    Object? data,
    _FeatureIds ids, {
    bool feature = false,
  }) {
    final writer = _GeoJsonWriter._(ids, write: true);
    try {
      writer._root(data, feature: feature);
    } catch (_) {
      return null;
    }
    return writer._text();
  }

  /// The indexes of the features of [data] that [_FeatureIds.markStringIds]
  /// marks, when [data] is GeoJSON of plain JSON values the platform channel
  /// takes as they are. Null when it takes the slow path.
  static List<int>? check(Object? data, _FeatureIds ids) {
    final writer = _GeoJsonWriter._(ids, write: false);
    try {
      writer._root(data, feature: false);
    } catch (_) {
      return null;
    }
    return writer._marked;
  }

  final _FeatureIds _ids;

  /// Whether it writes the text, or only checks.
  final bool _writing;

  /// The text: [_parts], then the Latin-1 code units of [_bytes] up to
  /// [_length]. A string to escape or wider than Latin-1 goes in [_parts], as
  /// `jsonEncode` writes it.
  Uint8List _bytes;
  int _length = 0;
  List<String>? _parts;

  /// The features to mark, collected when only checking.
  final List<int> _marked = [];

  /// How deep the lists and maps being written are nested. Data nested
  /// deeper than [_maxDepth], a cycle included, takes the slow path.
  int _depth = 0;
  static const _maxDepth = 64;

  void _root(Object? data, {required bool feature}) {
    final json = _resolve(data);
    if (json is! Map) throw const _GiveUp();
    final type = _resolve(json['type']);
    if (type == 'Feature') {
      _feature(json, 0);
    } else if (feature) {
      throw const _GiveUp();
    } else if (type == 'FeatureCollection') {
      _collection(json);
    } else {
      _geometry(json);
    }
  }

  void _collection(Map json) {
    var hasFeatures = false;
    _char(_openBrace);
    var first = true;
    for (final MapEntry(:key, :value) in json.entries) {
      _key(key, first: first);
      first = false;
      if (key != 'features') {
        _value(value);
        continue;
      }
      final features = _resolve(value);
      if (features is! List) throw const _GiveUp();
      hasFeatures = true;
      _char(_openBracket);
      for (var i = 0; i < features.length; i++) {
        if (i > 0) _char(_comma);
        final feature = _resolve(features[i]);
        if (feature is! Map) throw const _GiveUp();
        _feature(feature, i);
      }
      _char(_closeBracket);
    }
    if (!hasFeatures) throw const _GiveUp();
    _char(_closeBrace);
  }

  /// Writes the Feature at [index] of its collection, 0 for a lone one.
  void _feature(Map feature, int index) {
    var mark = false;
    if (_ids == _FeatureIds.markStringIds) {
      final id = feature['id'];
      mark = id is String && _MapLibreNativePlatform._numericText.hasMatch(id);
      if (mark && !_writing) _marked.add(index);
    }
    final generate = _ids == _FeatureIds.generate;
    var hasType = false;
    var hasGeometry = false;
    var hasProperties = false;
    var hasId = false;
    _char(_openBrace);
    var first = true;
    feature.forEach((key, value) {
      _key(key, first: first);
      first = false;
      switch (key) {
        case 'type':
          if (_resolve(value) != 'Feature') throw const _GiveUp();
          hasType = true;
          _value(value);
        case 'geometry':
          hasGeometry = true;
          final geometry = _resolve(value);
          if (geometry == null) {
            _literal('null');
          } else {
            _geometry(geometry);
          }
        case 'properties':
          hasProperties = true;
          final properties = _resolve(value);
          if (properties != null && properties is! Map) {
            throw const _GiveUp();
          }
          if (mark) {
            _markedProperties(properties as Map?);
          } else {
            _value(properties);
          }
        case 'id':
          hasId = true;
          final id = _resolve(value);
          if (id is! String && (id is! num || !id.isFinite)) {
            throw const _GiveUp();
          }
          _value(generate ? index : id);
        default:
          _value(value);
      }
    });
    if (!hasType || !hasGeometry) throw const _GiveUp();
    if (generate && !hasId) {
      _key('id', first: false);
      _value(index);
    }
    if (mark && !hasProperties) {
      _key('properties', first: false);
      _markedProperties(null);
    }
    _char(_closeBrace);
  }

  /// Writes [properties] with [_MapLibreNativePlatform._stringIdMarker]
  /// added at the end.
  void _markedProperties(Map? properties) {
    const marker = _MapLibreNativePlatform._stringIdMarker;
    if (properties != null && properties.containsKey(marker)) {
      throw const _GiveUp();
    }
    _char(_openBrace);
    var first = true;
    properties?.forEach((key, value) {
      _key(key, first: first);
      first = false;
      _value(value);
    });
    _key(marker, first: first);
    _literal('true');
    _char(_closeBrace);
  }

  void _geometry(Object? data) {
    final geometry = _resolve(data);
    if (geometry is! Map || ++_depth > _maxDepth) throw const _GiveUp();
    final type = _resolve(geometry['type']);
    final collection = type == 'GeometryCollection';
    final depth = collection ? 0 : _positionDepth(type);
    var hasMember = false;
    _char(_openBrace);
    var first = true;
    geometry.forEach((key, value) {
      _key(key, first: first);
      first = false;
      if (collection && key == 'geometries') {
        final geometries = _resolve(value);
        if (geometries is! List) throw const _GiveUp();
        hasMember = true;
        _char(_openBracket);
        for (var i = 0; i < geometries.length; i++) {
          if (i > 0) _char(_comma);
          _geometry(geometries[i]);
        }
        _char(_closeBracket);
      } else if (!collection && key == 'coordinates') {
        final coordinates = _resolve(value);
        if (coordinates is! List) throw const _GiveUp();
        hasMember = true;
        _positions(coordinates, depth);
      } else {
        _value(value);
      }
    });
    if (!hasMember) throw const _GiveUp();
    _char(_closeBrace);
    _depth--;
  }

  /// How deep the positions of a geometry of [type] are nested in its
  /// `coordinates`, as [geoJsonError] reads them.
  static int _positionDepth(Object? type) => switch (type) {
    'Point' => 0,
    'MultiPoint' || 'LineString' => 1,
    'MultiLineString' || 'Polygon' => 2,
    'MultiPolygon' => 3,
    _ => throw const _GiveUp(),
  };

  void _positions(List coordinates, int depth) {
    if (depth == 0) {
      _position(coordinates);
      return;
    }
    _char(_openBracket);
    for (var i = 0; i < coordinates.length; i++) {
      if (i > 0) _char(_comma);
      final child = coordinates[i];
      final list = child is List ? child : _resolve(child);
      if (list is! List) throw const _GiveUp();
      _positions(list, depth - 1);
    }
    _char(_closeBracket);
  }

  void _position(List position) {
    final length = position.length;
    if (length < 2) throw const _GiveUp();
    _char(_openBracket);
    _coordinate(position[0]);
    _char(_comma);
    _coordinate(position[1]);
    for (var i = 2; i < length; i++) {
      _char(_comma);
      _value(position[i]);
    }
    _char(_closeBracket);
  }

  void _coordinate(Object? value) {
    final number = value is num ? value : _resolve(value);
    if (number is! num || !number.isFinite) throw const _GiveUp();
    if (_writing) _ascii(number.toString());
  }

  /// Writes [value] as `jsonEncode` does.
  void _value(Object? value) {
    if (value is String) {
      _string(value);
    } else if (value is num) {
      if (!value.isFinite) throw const _GiveUp();
      if (_writing) _ascii(value.toString());
    } else if (value is bool) {
      _literal(value ? 'true' : 'false');
    } else if (value == null) {
      _literal('null');
    } else if (value is List) {
      if (++_depth > _maxDepth) throw const _GiveUp();
      _char(_openBracket);
      for (var i = 0; i < value.length; i++) {
        if (i > 0) _char(_comma);
        _value(value[i]);
      }
      _char(_closeBracket);
      _depth--;
    } else if (value is Map) {
      if (++_depth > _maxDepth) throw const _GiveUp();
      _char(_openBrace);
      var first = true;
      value.forEach((key, item) {
        _key(key, first: first);
        first = false;
        _value(item);
      });
      _char(_closeBrace);
      _depth--;
    } else {
      final json = _resolve(value);
      // jsonEncode takes only a JSON value from toJson().
      if (json is! String &&
          json is! num &&
          json is! bool &&
          json is! List &&
          json is! Map &&
          json != null) {
        throw const _GiveUp();
      }
      _value(json);
    }
  }

  /// [value], or what its `toJson()` returns when it is not a JSON value.
  /// When only checking, such an object takes the slow path, which replaces it
  /// for the platform channel.
  Object? _resolve(Object? value) {
    if (value == null ||
        value is String ||
        value is num ||
        value is bool ||
        value is List ||
        value is Map) {
      return value;
    }
    if (!_writing) throw const _GiveUp();
    return (value as dynamic).toJson();
  }

  void _key(Object? key, {required bool first}) {
    if (key is! String) throw const _GiveUp();
    if (!first) _char(_comma);
    _string(key);
    _char(_colon);
  }

  void _string(String value) {
    if (!_writing) return;
    final length = value.length;
    _reserve(length + 2);
    final bytes = _bytes;
    var at = _length;
    bytes[at++] = _quote;
    for (var i = 0; i < length; i++) {
      final unit = value.codeUnitAt(i);
      // What jsonEncode escapes, and what Latin-1 cannot hold.
      if (unit < 0x20 || unit == _quote || unit == _backslash || unit > 0xff) {
        _part(jsonEncode(value));
        return;
      }
      bytes[at++] = unit;
    }
    bytes[at++] = _quote;
    _length = at;
  }

  /// Writes [text], which is ASCII and needs no escaping.
  void _ascii(String text) {
    final length = text.length;
    _reserve(length);
    final bytes = _bytes;
    var at = _length;
    for (var i = 0; i < length; i++) {
      bytes[at++] = text.codeUnitAt(i);
    }
    _length = at;
  }

  void _literal(String text) {
    if (_writing) _ascii(text);
  }

  void _char(int unit) {
    if (!_writing) return;
    _reserve(1);
    _bytes[_length++] = unit;
  }

  /// Writes [text], JSON text that may hold any code unit.
  void _part(String text) {
    (_parts ??= []).add(String.fromCharCodes(_bytes, 0, _length));
    _parts!.add(text);
    _length = 0;
  }

  String _text() {
    final last = String.fromCharCodes(_bytes, 0, _length);
    final parts = _parts;
    return parts == null ? last : (parts..add(last)).join();
  }

  /// Makes room for [count] more code units.
  void _reserve(int count) {
    final needed = _length + count;
    if (needed <= _bytes.length) return;
    final grown = Uint8List(max(needed, _bytes.length * 2));
    grown.setRange(0, _length, _bytes);
    _bytes = grown;
  }

  static const _quote = 0x22;
  static const _comma = 0x2c;
  static const _colon = 0x3a;
  static const _openBracket = 0x5b;
  static const _backslash = 0x5c;
  static const _closeBracket = 0x5d;
  static const _openBrace = 0x7b;
  static const _closeBrace = 0x7d;
}

/// Thrown where [_GeoJsonWriter] leaves the data to the slow path.
class _GiveUp implements Exception {
  const _GiveUp();
}
