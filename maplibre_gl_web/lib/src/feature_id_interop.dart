/// The maplibre-gl-js side of [featureIdProperty]: see feature_ids.dart.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl_web/src/feature_ids.dart';
import 'package:web/web.dart' as web;

/// Copies the id of [feature], a GeoJSON Feature as maplibre-gl-js takes it,
/// into its [featureIdProperty]. A feature without an id is left as it is.
void copyFeatureId(JSObject feature) {
  final id = feature.getProperty<JSAny?>('id'.toJS);
  if (id == null) return;
  var properties = feature.getProperty<JSAny?>('properties'.toJS);
  if (properties == null || !properties.isA<JSObject>()) {
    properties = JSObject();
    feature.setProperty('properties'.toJS, properties);
  }
  (properties as JSObject).setProperty(featureIdProperty.toJS, id);
}

/// Whether [source], a GeoJSON source of maplibre-gl-js, takes its feature
/// ids from [featureIdProperty] now.
bool promotesFeatureIds(JSObject source) {
  final current = source.getProperty<JSAny?>('promoteId'.toJS);
  return current.isA<JSString>() &&
      (current! as JSString).toDart == featureIdProperty;
}

/// Makes [source], a GeoJSON source of maplibre-gl-js, take its feature ids
/// from [featureIdProperty] when [promote] is true, for data the plugin sets,
/// and from the data itself otherwise, for data loaded from a URL.
///
/// Answers whether the source now takes them from [featureIdProperty]. A
/// source that the app or the style gave a `promoteId` of its own keeps it,
/// and one with `generateId` keeps the ids maplibre-gl-js generates. When the
/// GeoJSON sources of the loaded maplibre-gl-js lack the fields set here,
/// nothing changes, and a warning names the missing one, once.
bool promoteFeatureIds(JSObject source, {required bool promote}) {
  // Without serialize() this is not a maplibre-gl-js GeoJSON source.
  if (!source.has('serialize')) return false;
  // serialize() answers the options the source was created with.
  final options = source.callMethod<JSObject?>('serialize'.toJS);
  if (options?.getProperty<JSAny?>('promoteId'.toJS) != null) return false;
  // promoteId takes precedence over generateId in maplibre-gl-js.
  final generateId = options?.getProperty<JSAny?>('generateId'.toJS);
  if (generateId.isA<JSBoolean>() && (generateId! as JSBoolean).toDart) {
    return false;
  }
  // maplibre-gl-js has no setter: it reads promoteId when it loads a tile,
  // and hands the worker its geojsonVtOptions with the next data.
  final vtOptions = source
      .getProperty<JSAny?>('workerOptions'.toJS)
      ?.getPropertyOrNull('geojsonVtOptions');
  final missing =
      !source.has('promoteId')
          ? 'promoteId'
          : vtOptions == null || !vtOptions.has('promoteId')
          ? 'workerOptions.geojsonVtOptions.promoteId'
          : null;
  if (missing != null) {
    _warnUnknownSource(missing);
    return false;
  }
  final value = promote ? featureIdProperty.toJS : null;
  source.setProperty('promoteId'.toJS, value);
  vtOptions!.setProperty('promoteId'.toJS, value);
  return promote;
}

/// Whether the warning of [_warnUnknownSource] was given.
bool _warned = false;

/// Warns, once, that the GeoJSON sources of the loaded maplibre-gl-js have
/// no field [missing], so feature ids stay the integers it keeps.
void _warnUnknownSource(String missing) {
  if (_warned) return;
  _warned = true;
  final message =
      'maplibre_gl: the GeoJSON sources of this maplibre-gl-js build have no '
      '$missing, so feature ids come back as maplibre-gl-js keeps them: '
      'integers only.';
  web.console.warn(message.toJS);
}

/// Lets the next [promoteFeatureIds] warn again.
@visibleForTesting
void debugResetFeatureIdWarning() => _warned = false;

extension on JSAny {
  /// The property [name] of this value when it is an object, or null.
  JSObject? getPropertyOrNull(String name) {
    if (!isA<JSObject>()) return null;
    final value = (this as JSObject).getProperty<JSAny?>(name.toJS);
    return value.isA<JSObject>() ? value! as JSObject : null;
  }
}
