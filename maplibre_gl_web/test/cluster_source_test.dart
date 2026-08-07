// Inspects real JS objects, so it needs a browser:
// `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/interop/style/sources/geojson_source_interop.dart';
import 'package:maplibre_gl_web/src/style/sources/geojson_source.dart';

/// The cluster-inspection wrappers are pure interop: nothing in Dart can tell
/// you that `getClusterLeaves(clusterId, limit, offset)` reached maplibre-gl-js
/// with its arguments in that order, or that the probe for the methods spells
/// their name the way the library does. Both are asserted here against real JS
/// objects, because a slip in either fails only at runtime, on a live map.
void main() {
  group('GeoJsonSource cluster inspection', () {
    test('hasClusterInspection is false without the methods', () {
      final source = GeoJsonSource.fromJsObject(
        JSObject() as GeoJsonSourceJsImpl,
      );

      expect(source.hasClusterInspection, isFalse);
    });

    test('hasClusterInspection finds the method maplibre-gl-js defines', () {
      final target =
          JSObject()..setProperty(
            'getClusterExpansionZoom'.toJS,
            ((JSNumber _) => Future<JSNumber>.value(3.toJS).toJS).toJS,
          );
      final source = GeoJsonSource.fromJsObject(
        target as GeoJsonSourceJsImpl,
      );

      expect(source.hasClusterInspection, isTrue);
    });

    test(
      'getClusterLeaves passes id, limit and offset in that order',
      () async {
        final received = <int>[];
        final target =
            JSObject()..setProperty(
              'getClusterLeaves'.toJS,
              ((JSNumber clusterId, JSNumber limit, JSNumber offset) {
                received
                  ..add(clusterId.toDartInt)
                  ..add(limit.toDartInt)
                  ..add(offset.toDartInt);
                return Future<JSArray<JSObject>>.value(<JSObject>[].toJS).toJS;
              }).toJS,
            );
        final source = GeoJsonSource.fromJsObject(
          target as GeoJsonSourceJsImpl,
        );

        await source.getClusterLeaves(42, 100, 7);

        expect(received, [42, 100, 7]);
      },
    );

    test('getClusterExpansionZoom unwraps the promise', () async {
      final target =
          JSObject()..setProperty(
            'getClusterExpansionZoom'.toJS,
            ((JSNumber _) => Future<JSNumber>.value(9.toJS).toJS).toJS,
          );
      final source = GeoJsonSource.fromJsObject(
        target as GeoJsonSourceJsImpl,
      );

      expect((await source.getClusterExpansionZoom(1)).toDartDouble, 9);
    });
  });
}
