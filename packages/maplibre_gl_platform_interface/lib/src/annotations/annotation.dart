part of maplibre_gl_platform_interface;

enum AnnotationType { fill, line, circle, symbol }

abstract class Annotation {
  String get id;
  Map<String, dynamic> toGeoJson();

  void translate(LatLng delta);
}
