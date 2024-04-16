part of maplibre_gl;

class CameraPositionController extends Stream<CameraPosition>
    implements CameraPosition {
  CameraPosition _position;
  CameraPositionController(CameraPosition initial) : _position = initial;

  final _controller = StreamController<CameraPosition>.broadcast();
  _set(CameraPosition cameraPosition) {
    _controller.add(cameraPosition);
    _position = cameraPosition;
  }

  Stream<CameraPosition> get _stream async* {
    yield _position;
    yield* _controller.stream.distinct();
  }

  @override
  double get bearing => _position.bearing;

  @override
  StreamSubscription<CameraPosition> listen(
      void Function(CameraPosition event)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  LatLng get target => _position.target;

  @override
  double get tilt => _position.tilt;

  @override
  toMap() => _position.toMap();

  @override
  double get zoom => _position.zoom;

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (runtimeType != other.runtimeType) return false;
    final CameraPosition typedOther = other;
    return bearing == typedOther.bearing &&
        target == typedOther.target &&
        tilt == typedOther.tilt &&
        zoom == typedOther.zoom;
  }
}
