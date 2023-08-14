import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import 'package:maplibre_gl_example/page.dart';

class TripCalculationPage extends ExamplePage {
  const TripCalculationPage({super.key})
      : super(const Icon(Icons.trip_origin), 'Trip calculation example');

  @override
  Widget build(BuildContext context) {
    return const TripCalculationExampleBody();
  }
}

class TripCalculationExampleBody extends StatefulWidget {
  const TripCalculationExampleBody({super.key});

  @override
  State<TripCalculationExampleBody> createState() =>
      _TripCalculationExampleBodyState();
}

class _TripCalculationExampleBodyState
    extends State<TripCalculationExampleBody> {
  final _controllerCompleter = Completer<MaplibreMapController>();
  LatLng? origin;
  Symbol? originSymbol;

  LatLng? destination;
  Symbol? destinationSymbol;
  Line? _route;

  final _boundingBox = BoundingBoxConstraint();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MaplibreMap(
            trackCameraPosition: true,
            tiltGesturesEnabled: false,
            myLocationEnabled: false,
            compassEnabled: false,
            cameraTargetBounds: _boundingBox.bounds,
            minMaxZoomPreference: _boundingBox.zoomPreference,
            initialCameraPosition: const CameraPosition(
              target: LatLng(50.834060793873505, 4.340443996254663),
              zoom: 12,
            ),
            onMapCreated: (controller) =>
                _controllerCompleter.complete(controller),
            onMapClick: _onMapClick,
          ),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (origin != null && destination != null) ...[
                    ElevatedButton.icon(
                      onPressed: _calculateRoute,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Calculate Route"),
                    ),
                    ElevatedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.delete),
                      label: const Text("Reset"),
                    ),
                  ],
                  if (origin == null && destination == null) ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("Tap on the screen to select a point"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _didAddImage = false;

  Future<void> _onMapClick(Point<double> point, LatLng coordinate) async {
    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    const markerImageName = "custom-marker";

    if (!_didAddImage) {
      final bytes = await rootBundle.load("assets/symbols/custom-marker.png");
      await controller.addImage(markerImageName, bytes.buffer.asUint8List());
    }

    final symbolOptions = SymbolOptions(
      geometry: coordinate,
      iconSize: 1.4,
      iconImage: markerImageName,
    );

    if (origin == null) {
      originSymbol = await controller.addSymbol(symbolOptions);
      setState(() => origin = coordinate);
    } else {
      if (destinationSymbol != null) {
        await controller.removeSymbol(destinationSymbol!);
      }
      destinationSymbol = await controller.addSymbol(symbolOptions);
      setState(() => destination = coordinate);
    }

    var zoom = controller.cameraPosition?.zoom ?? 0;

    const targetZoom = 16.5;
    final zoomDiff = (zoom - targetZoom).abs();
    if (zoomDiff <= 2) {
      await controller.animateCamera(CameraUpdate.newLatLng(coordinate));
    } else {
      await controller
          .animateCamera(CameraUpdate.newLatLngZoom(coordinate, targetZoom));
    }
  }

  Future<void> _reset() async {
    final controller = await _controllerCompleter.future;
    if (!mounted) return;
    await controller.removeSymbols(
        [originSymbol, destinationSymbol].whereNotNull().toList());
    if (_route != null) {
      await controller.removeLine(_route!);
    }

    setState(() {
      origin = null;
      destination = null;
    });
  }

  Future<void> _calculateRoute() async {
    if (_route != null) return;

    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    final points = [origin!, destination!];
    final route = await controller.addLine(LineOptions(geometry: points));
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        points.convertToBounds(),
        top: 24 + MediaQuery.of(context).padding.top + kToolbarHeight,
        left: 64,
        right: 64,
        bottom: 300,
      ),
      duration: const Duration(seconds: 2),
    );
    if (!mounted) return;

    setState(() => _route = route);
  }
}

extension on List<LatLng> {
  // https://stackoverflow.com/a/66545600/9277334
  LatLngBounds convertToBounds() {
    final route = this;

    assert(route.isNotEmpty);
    final firstLatLng = route.first;
    var s = firstLatLng.latitude,
        n = firstLatLng.latitude,
        w = firstLatLng.longitude,
        e = firstLatLng.longitude;
    for (var i = 1; i < route.length; i++) {
      final latlng = this[i];
      s = min(s, latlng.latitude);
      n = max(n, latlng.latitude);
      w = min(w, latlng.longitude);
      e = max(e, latlng.longitude);
    }
    return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
  }
}

class BoundingBoxConstraint {
  // From: https://gist.github.com/graydon/11198540
  final _mobileMapBounds = CameraTargetBounds(
    LatLngBounds(
      northeast: const LatLng(51.4750237087, 6.15665815596),
      southwest: const LatLng(49.5294835476, 2.51357303225),
    ),
  );

  /// If this is not added, the user could zoom out way too much, that almost everything
  /// of the world is visible, but we don't have the whole world rendered.
  final zoomPreference = const MinMaxZoomPreference(5.85, 25);

  CameraTargetBounds get bounds {
    return _mobileMapBounds;
  }
}
