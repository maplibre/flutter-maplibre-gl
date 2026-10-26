import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  late MapLibrePlatform Function() unregistered;

  setUp(() => unregistered = MapLibrePlatform.createInstance);
  tearDown(() => MapLibrePlatform.createInstance = unregistered);

  test('is not registered until a factory is installed', () {
    expect(MapLibrePlatform.isRegistered, isFalse);

    MapLibrePlatform.createInstance = unregistered;
    expect(MapLibrePlatform.isRegistered, isFalse);

    MapLibrePlatform.createInstance = () => unregistered();
    expect(MapLibrePlatform.isRegistered, isTrue);
  });

  // A desktop app, for instance, has no implementation: the map says so
  // instead of failing to build.
  testWidgets('the default shows that the platform is not supported', (
    tester,
  ) async {
    final platform = unregistered();

    await tester.pumpWidget(
      MaterialApp(home: platform.buildView({}, (_) {}, null)),
    );

    expect(find.textContaining('is not yet supported'), findsOneWidget);
    platform.dispose();
  });

  test('the default answers no call', () {
    expect(
      () => unregistered().initPlatform(1),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('No MapLibre implementation is registered'),
        ),
      ),
    );
  });
}
