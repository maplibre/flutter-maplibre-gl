import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('MapLibreColorConversion', () {
    test('red converts to #ff0000', () {
      expect(const Color(0xFFFF0000).toHexStringRGB(), '#ff0000');
    });

    test('green converts to #00ff00', () {
      expect(const Color(0xFF00FF00).toHexStringRGB(), '#00ff00');
    });

    test('blue converts to #0000ff', () {
      expect(const Color(0xFF0000FF).toHexStringRGB(), '#0000ff');
    });

    test('white converts to #ffffff', () {
      expect(const Color(0xFFFFFFFF).toHexStringRGB(), '#ffffff');
    });

    test('black converts to #000000', () {
      expect(const Color(0xFF000000).toHexStringRGB(), '#000000');
    });

    test('alpha channel is ignored', () {
      // Same RGB but different alpha
      expect(const Color(0x80FF0000).toHexStringRGB(), '#ff0000');
      expect(const Color(0x00FF0000).toHexStringRGB(), '#ff0000');
    });

    test('single-digit hex values are zero-padded', () {
      expect(const Color(0xFF010203).toHexStringRGB(), '#010203');
    });
  });
}
