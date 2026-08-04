import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_native/src/presentation/platform/map_options.dart';
import 'package:maplibre_gl_native/src/protocol/protocol.dart';
import 'package:maplibre_gl_native/src/utils/projection.dart';

/// The maplibre_gl options-map decoding: the well-formed shapes the plugin
/// serializes, and the degenerate ones (short lists, wrong types) that must
/// constrain nothing instead of crashing the whole options batch.
void main() {
  const sessionId = 3;

  group('cameraConstraintCommands', () {
    test('an options map without constraint keys asks for nothing', () {
      expect(cameraConstraintCommands(<String, dynamic>{}, sessionId), isEmpty);
    });

    test('a bounds list decodes as [[swLat, swLng], [neLat, neLng]]', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'cameraTargetBounds': [
          [
            [-10, 20],
            [30, 40],
          ],
        ],
      }, sessionId);
      final command = commands.single as SetBoundsCommand;
      expect(command.sessionId, sessionId);
      final bounds = command.bounds!.bounds!;
      expect(bounds.south, -10);
      expect(bounds.west, 20);
      expect(bounds.north, 30);
      expect(bounds.east, 40);
      expect(command.minZoom, isNull);
      expect(command.maxZoom, isNull);
    });

    test('a null bounds entry (CameraTargetBounds.unbounded) removes the '
        'constraint', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'cameraTargetBounds': [null],
      }, sessionId);
      final command = commands.single as SetBoundsCommand;
      expect(command.bounds, isNotNull);
      expect(command.bounds!.bounds, isNull);
    });

    test('an empty cameraTargetBounds list also means unbounded', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'cameraTargetBounds': <dynamic>[],
      }, sessionId);
      final command = commands.single as SetBoundsCommand;
      expect(command.bounds!.bounds, isNull);
    });

    test('a min/max zoom preference decodes both ends', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'minMaxZoomPreference': [5, 15],
      }, sessionId);
      final command = commands.single as SetBoundsCommand;
      expect(command.minZoom, 5);
      expect(command.maxZoom, 15);
      expect(command.bounds, isNull);
    });

    test('null zoom ends clear the preference to the projection limits', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'minMaxZoomPreference': [null, null],
      }, sessionId);
      final command = commands.single as SetBoundsCommand;
      expect(command.minZoom, MapLimits.minZoom);
      expect(command.maxZoom, MapLimits.maxZoom);
    });

    test('both constraints come back in send order: bounds first', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'cameraTargetBounds': [null],
        'minMaxZoomPreference': [2, 18],
      }, sessionId);
      expect(commands, hasLength(2));
      expect((commands[0] as SetBoundsCommand).bounds, isNotNull);
      expect((commands[1] as SetBoundsCommand).minZoom, 2);
    });

    test('a malformed bounds entry constrains nothing instead of crashing '
        'or silently unbounding', () {
      final degenerateEntries = <Object>[
        'bogus', // not a list at all
        <dynamic>[], // no corners
        [
          [1, 2],
        ], // missing the northeast corner
        [
          [1],
          [2, 3],
        ], // a corner with one coordinate
        [
          ['a', 'b'],
          [2, 3],
        ], // non-numeric coordinates
      ];
      for (final entry in degenerateEntries) {
        final commands = cameraConstraintCommands(<String, dynamic>{
          'cameraTargetBounds': [entry],
        }, sessionId);
        expect(commands, isEmpty, reason: 'entry: $entry');
      }
    });

    test('a too-short min/max zoom list constrains nothing', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'minMaxZoomPreference': [5],
      }, sessionId);
      expect(commands, isEmpty);
    });

    test('non-numeric zoom ends clear that side instead of crashing', () {
      final commands = cameraConstraintCommands(<String, dynamic>{
        'minMaxZoomPreference': ['low', 15],
      }, sessionId);
      final command = commands.single as SetBoundsCommand;
      expect(command.minZoom, MapLimits.minZoom);
      expect(command.maxZoom, 15);
    });
  });

  group('applyGestureOptions', () {
    test('applies every gesture flag and routes the feature-tap option', () {
      final gestures = GestureConfig();
      bool? featureTaps;
      applyGestureOptions(
        <String, dynamic>{
          'scrollGesturesEnabled': false,
          'zoomGesturesEnabled': false,
          'rotateGesturesEnabled': false,
          'tiltGesturesEnabled': false,
          'doubleClickZoomEnabled': false,
          'featureTapsTriggersMapClick': true,
        },
        gestures: gestures,
        setFeatureTapsTriggersMapClick: (v) => featureTaps = v,
      );
      expect(gestures.scrollEnabled, isFalse);
      expect(gestures.zoomEnabled, isFalse);
      expect(gestures.rotateEnabled, isFalse);
      expect(gestures.tiltEnabled, isFalse);
      expect(gestures.doubleClickZoomEnabled, isFalse);
      expect(featureTaps, isTrue);
    });

    test('missing keys and non-bool values leave the flags untouched', () {
      final gestures = GestureConfig()..scrollEnabled = false;
      var featureTapsCalls = 0;
      applyGestureOptions(
        <String, dynamic>{
          'zoomGesturesEnabled': 'yes', // wrong type: ignored
          'featureTapsTriggersMapClick': 1, // wrong type: ignored
        },
        gestures: gestures,
        setFeatureTapsTriggersMapClick: (_) => featureTapsCalls++,
      );
      expect(gestures.scrollEnabled, isFalse); // untouched, not reset
      expect(gestures.zoomEnabled, isTrue);
      expect(featureTapsCalls, 0);
    });
  });
}
