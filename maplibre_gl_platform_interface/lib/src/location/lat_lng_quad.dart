part of maplibre_gl_platform_interface;

/// A geographical area representing a non-aligned quadrilateral
/// This class does not wrap values to the world bounds
class LatLngQuad {
  const LatLngQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final LatLng topLeft;

  final LatLng topRight;

  final LatLng bottomRight;

  final LatLng bottomLeft;

  dynamic toList() {
    return <dynamic>[
      topLeft.toJson(),
      topRight.toJson(),
      bottomRight.toJson(),
      bottomLeft.toJson()
    ];
  }

  static LatLngQuad? fromList(dynamic json) {
    if (json == null) {
      return null;
    }
    return LatLngQuad(
      topLeft: LatLng._fromJson(json[0]),
      topRight: LatLng._fromJson(json[1]),
      bottomRight: LatLng._fromJson(json[2]),
      bottomLeft: LatLng._fromJson(json[3]),
    );
  }

  @override
  String toString() {
    return '$runtimeType($topLeft, $topRight, $bottomRight, $bottomLeft)';
  }

  @override
  bool operator ==(Object o) {
    return o is LatLngQuad &&
        o.topLeft == topLeft &&
        o.topRight == topRight &&
        o.bottomRight == bottomRight &&
        o.bottomLeft == bottomLeft;
  }

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);
}
