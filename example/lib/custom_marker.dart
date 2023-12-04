import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // ignore: unnecessary_import
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';

const randomMarkerNum = 100;

class CustomMarkerPage extends ExamplePage {
  const CustomMarkerPage({super.key})
      : super(const Icon(Icons.place), 'Custom marker');

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

  late MaplibreMapController _mapController;
  final _markers = <Marker>[];
  final _markerStates = <MarkerState>[];

  void _addMarkerStates(MarkerState markerState) {
    _markerStates.add(markerState);
  }

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
    controller.addListener(() {
      if (controller.isCameraMoving) {
        _updateMarkerPosition();
      }
    });
  }

  void _onStyleLoadedCallback() {
    debugPrint('onStyleLoadedCallback');
  }

  void _onMapLongClickCallback(Point<double> point, LatLng coordinates) {
    _addMarker(point, coordinates);
  }

  void _onCameraIdleCallback() {
    _updateMarkerPosition();
  }

  void _updateMarkerPosition() {
    final coordinates = <LatLng>[];

    for (final markerState in _markerStates) {
      coordinates.add(markerState.getCoordinate());
    }

    _mapController.toScreenLocationBatch(coordinates).then((points) {
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
        MaplibreMap(
          trackCameraPosition: true,
          onMapCreated: _onMapCreated,
          onMapLongClick: _onMapLongClickCallback,
          onCameraIdle: _onCameraIdleCallback,
          onStyleLoadedCallback: _onStyleLoadedCallback,
          initialCameraPosition:
              const CameraPosition(target: LatLng(35.0, 135.0), zoom: 5),
        ),
        IgnorePointer(
            ignoring: true,
            child: Stack(
              children: _markers,
            ))
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          //_measurePerformance();

          // Generate random markers
          var param = <LatLng>[];
          for (var i = 0; i < randomMarkerNum; i++) {
            final lat = _rnd.nextDouble() * 20 + 30;
            final lng = _rnd.nextDouble() * 20 + 125;
            param.add(LatLng(lat, lng));
          }

          _mapController.toScreenLocationBatch(param).then((value) {
            for (var i = 0; i < randomMarkerNum; i++) {
              var point =
                  Point<double>(value[i].x as double, value[i].y as double);
              _addMarker(point, param[i]);
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ignore: unused_element
  void _measurePerformance() {
    const trial = 10;
    final batches = [500, 1000, 1500, 2000, 2500, 3000];
    final results = <int, List<double>>{};
    for (final batch in batches) {
      results[batch] = [0.0, 0.0];
    }

    _mapController.toScreenLocation(const LatLng(0, 0));
    Stopwatch sw = Stopwatch();

    for (final batch in batches) {
      //
      // primitive
      //
      for (var i = 0; i < trial; i++) {
        sw.start();
        var list = <Future<Point<num>>>[];
        for (var j = 0; j < batch; j++) {
          var p = _mapController
              .toScreenLocation(LatLng(j.toDouble() % 80, j.toDouble() % 300));
          list.add(p);
        }
        Future.wait(list);
        sw.stop();
        results[batch]![0] += sw.elapsedMilliseconds;
        sw.reset();
      }

      //
      // batch
      //
      for (var i = 0; i < trial; i++) {
        sw.start();
        var param = <LatLng>[];
        for (var j = 0; j < batch; j++) {
          param.add(LatLng(j.toDouble() % 80, j.toDouble() % 300));
        }
        Future.wait([_mapController.toScreenLocationBatch(param)]);
        sw.stop();
        results[batch]![1] += sw.elapsedMilliseconds;
        sw.reset();
      }

      debugPrint(
        'batch=$batch,primitive=${results[batch]![0] / trial}ms, batch=${results[batch]![1] / trial}ms',
      );
    }
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
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var ratio = 1.0;

    //web does not support Platform._operatingSystem
    if (!kIsWeb) {
      // iOS returns logical pixel while Android returns screen pixel
      ratio = Platform.isIOS ? 1.0 : MediaQuery.of(context).devicePixelRatio;
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
