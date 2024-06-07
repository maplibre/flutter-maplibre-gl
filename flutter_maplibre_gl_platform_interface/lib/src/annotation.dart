part of '../maplibre_gl_platform_interface.dart';

abstract class Annotation {
  String get id;
  Map<String, dynamic> toGeoJson();

  void translate(LatLng delta);
}
