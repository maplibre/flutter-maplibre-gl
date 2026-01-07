import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';

const randomMarkerNum = 100;

class CustomMarkerPage extends ExamplePage {
  const CustomMarkerPage({super.key})
      : super(const Icon(Icons.place), 'Custom marker',
            category: ExampleCategory.annotations);

  @override
  Widget build(BuildContext context) {
    return const CustomMarker();
  }
}

class CustomMarker extends StatefulWidget {
  const CustomMarker({super.key});

  @override
  State createState() => CustomMarkerState();
}

class CustomMarkerState extends State<CustomMarker> {
  final _rnd = Random();

  MapLibreMapController? _mapController;
  final _markers = <Marker>[];
  final _markerStates = <MarkerState>[];

  void _addMarkerStates(MarkerState markerState) {
    _markerStates.add(markerState);
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _mapController = controller);

    controller.addListener(() async {
      if (controller.isCameraMoving) {
        await _updateMarkerPosition();
      }
    });
  }

  void _onStyleLoadedCallback() {
    debugPrint('onStyleLoadedCallback');
  }

  void _onMapLongClickCallback(Point<double> point, LatLng coordinates) {
    _addMarker(point, coordinates);
  }

  Future<void> _onCameraIdleCallback() async {
    await _updateMarkerPosition();
  }

  Future<void> _updateMarkerPosition() async {
    final coordinates = <LatLng>[];

    for (final markerState in _markerStates) {
      coordinates.add(markerState.getCoordinate());
    }

    await _mapController?.toScreenLocationBatch(coordinates).then((points) {
      _markerStates.asMap().forEach((i, value) {
        _markerStates[i].updatePosition(points[i]);
      });
    });
  }

  void _addMarker(Point<double> point, LatLng coordinates) {
    setState(() {
      _markers.add(
        Marker(
          _rnd.nextInt(100000).toString(),
          coordinates,
          point,
          _addMarkerStates,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        MapLibreMap(
          trackCameraPosition: true,
          onMapCreated: _onMapCreated,
          onMapLongClick: _onMapLongClickCallback,
          onCameraIdle: _onCameraIdleCallback,
          onStyleLoadedCallback: _onStyleLoadedCallback,
          initialCameraPosition:
              const CameraPosition(target: LatLng(35.0, 135.0), zoom: 5),
          iosLongClickDuration: const Duration(milliseconds: 200),
        ),
        IgnorePointer(
            ignoring: true,
            child: Stack(
              children: _markers,
            ))
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          //_measurePerformance();

          // Generate random markers
          final param = <LatLng>[];
          for (var i = 0; i < randomMarkerNum; i++) {
            final lat = _rnd.nextDouble() * 20 + 30;
            final lng = _rnd.nextDouble() * 20 + 125;
            param.add(LatLng(lat, lng));
          }

          await _mapController?.toScreenLocationBatch(param).then((value) {
            for (var i = 0; i < randomMarkerNum; i++) {
              final point =
                  Point<double>(value[i].x as double, value[i].y as double);
              _addMarker(point, param[i]);
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Marker extends StatefulWidget {
  final Point initialPosition;
  final LatLng _coordinate;
  final void Function(MarkerState) addMarkerState;

  Marker(
    String key,
    this._coordinate,
    this.initialPosition,
    this.addMarkerState,
  ) : super(key: Key(key));

  @override
  State<StatefulWidget> createState() {
    return MarkerState();
  }
}

class MarkerState extends State<Marker> with TickerProviderStateMixin {
  final _iconSize = 20.0;

  late Point _position;

  late AnimationController _controller;
  late Animation<double> _animation;

  MarkerState();

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    widget.addMarkerState(this);

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
      // ignore: discarded_futures --- IGNORE ---
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    var ratio = 1.0;

    //web does not support Platform._operatingSystem
    if (!kIsWeb) {
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;

      // iOS returns logical pixel while Android returns screen pixel
      ratio = isIos ? 1.0 : MediaQuery.of(context).devicePixelRatio;
    }

    return Positioned(
        left: _position.x / ratio - _iconSize / 2,
        top: _position.y / ratio - _iconSize / 2,
        child: RotationTransition(
            turns: _animation,
            child: Image.asset('assets/symbols/2.0x/custom-icon.png',
                height: _iconSize)));
  }

  void updatePosition(Point<num> point) {
    setState(() {
      _position = point;
    });
  }

  LatLng getCoordinate() {
    return widget._coordinate;
  }
}
