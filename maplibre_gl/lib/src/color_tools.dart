part of '../maplibre_gl.dart';

extension MapLibreColorConversion on Color {
  String toHexStringRGB() {
    final r = this.r.toRadixString(16).padLeft(2, '0');
    final g = this.g.toRadixString(16).padLeft(2, '0');
    final b = this.b.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}
