import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

// MyLocationStyle.toJson is what the Android, iOS and web code read, key by
// key. A misspelled key or a color sent in another format is not rejected
// there, it is ignored, so the puck silently keeps its default look. Each
// field gets a distinct value so a swapped key does not pass unnoticed.
void main() {
  const full = MyLocationStyle(
    fillColor: Color(0xFFFF0000),
    bearingColor: Color(0xFF00FF00),
    accuracyColor: Color(0x800000FF),
    accuracyCircleEnabled: false,
    pulseEnabled: true,
    pulseColor: Color(0x40FFFF00),
  );

  group('MyLocationStyle defaults', () {
    test('leave every color unset and keep the accuracy circle', () {
      const style = MyLocationStyle();
      expect(style.fillColor, isNull);
      expect(style.bearingColor, isNull);
      expect(style.accuracyColor, isNull);
      expect(style.accuracyCircleEnabled, isTrue);
      expect(style.pulseEnabled, isNull);
      expect(style.pulseColor, isNull);
    });

    test('serialize to the accuracy circle flag alone', () {
      expect(const MyLocationStyle().toJson(), {
        'accuracyCircleEnabled': true,
      });
    });
  });

  group('MyLocationStyle.toJson', () {
    test('sends every field, colors as ARGB ints with their alpha', () {
      expect(full.toJson(), {
        'fillColor': 0xFFFF0000,
        'bearingColor': 0xFF00FF00,
        'accuracyColor': 0x800000FF,
        'accuracyCircleEnabled': false,
        'pulseEnabled': true,
        'pulseColor': 0x40FFFF00,
      });
    });

    test('leaves out each null field on its own', () {
      expect(const MyLocationStyle(fillColor: Color(0xFF010203)).toJson(), {
        'fillColor': 0xFF010203,
        'accuracyCircleEnabled': true,
      });
      expect(const MyLocationStyle(bearingColor: Color(0xFF010203)).toJson(), {
        'bearingColor': 0xFF010203,
        'accuracyCircleEnabled': true,
      });
      expect(const MyLocationStyle(accuracyColor: Color(0xFF010203)).toJson(), {
        'accuracyColor': 0xFF010203,
        'accuracyCircleEnabled': true,
      });
      expect(const MyLocationStyle(pulseColor: Color(0xFF010203)).toJson(), {
        'pulseColor': 0xFF010203,
        'accuracyCircleEnabled': true,
      });
    });

    test('sends pulseEnabled false, which differs from leaving it unset', () {
      expect(const MyLocationStyle(pulseEnabled: false).toJson(), {
        'accuracyCircleEnabled': true,
        'pulseEnabled': false,
      });
    });

    test('keeps a transparent color instead of dropping it', () {
      expect(
        const MyLocationStyle(fillColor: Color(0x00000000)).toJson(),
        containsPair('fillColor', 0),
      );
    });
  });

  group('MyLocationStyle equality', () {
    test('holds for the same values', () {
      const copy = MyLocationStyle(
        fillColor: Color(0xFFFF0000),
        bearingColor: Color(0xFF00FF00),
        accuracyColor: Color(0x800000FF),
        accuracyCircleEnabled: false,
        pulseEnabled: true,
        pulseColor: Color(0x40FFFF00),
      );
      expect(copy, full);
      expect(copy.hashCode, full.hashCode);
      expect(const MyLocationStyle(), const MyLocationStyle());
    });

    test('breaks on any single field', () {
      const variants = [
        MyLocationStyle(fillColor: Color(0xFF000001)),
        MyLocationStyle(bearingColor: Color(0xFF000001)),
        MyLocationStyle(accuracyColor: Color(0xFF000001)),
        MyLocationStyle(accuracyCircleEnabled: false),
        MyLocationStyle(pulseEnabled: true),
        MyLocationStyle(pulseEnabled: false),
        MyLocationStyle(pulseColor: Color(0xFF000001)),
      ];
      for (final variant in variants) {
        expect(variant, isNot(const MyLocationStyle()), reason: '$variant');
      }
      expect(
        const MyLocationStyle(pulseEnabled: true),
        isNot(const MyLocationStyle(pulseEnabled: false)),
      );
    });

    test('is false against another type', () {
      // Comparing with another type is the point of this test.
      // ignore: unrelated_type_equality_checks
      expect(const MyLocationStyle() == 'MyLocationStyle()', isFalse);
    });
  });

  test('toString names every field', () {
    final text = full.toString();
    for (final field in [
      'fillColor',
      'bearingColor',
      'accuracyColor',
      'accuracyCircleEnabled: false',
      'pulseEnabled: true',
      'pulseColor',
    ]) {
      expect(text, contains(field));
    }
    expect(text, startsWith('MyLocationStyle('));
  });
}
