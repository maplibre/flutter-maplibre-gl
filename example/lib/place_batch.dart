// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

import 'page.dart';
import 'util.dart';

const fillOptions = [
  FillOptions(
    geometry: [
      [
        LatLng(-33.719, 151.150),
        LatLng(-33.858, 151.150),
        LatLng(-33.866, 151.401),
        LatLng(-33.747, 151.328),
        LatLng(-33.719, 151.150),
      ],
      [
        LatLng(-33.762, 151.250),
        LatLng(-33.827, 151.250),
        LatLng(-33.833, 151.347),
        LatLng(-33.762, 151.250),
      ]
    ],
    fillColor: "#FF0000",
  ),
  FillOptions(geometry: [
    [
      LatLng(-33.719, 151.550),
      LatLng(-33.858, 151.550),
      LatLng(-33.866, 151.801),
      LatLng(-33.747, 151.728),
      LatLng(-33.719, 151.550),
    ],
    [
      LatLng(-33.762, 151.650),
      LatLng(-33.827, 151.650),
      LatLng(-33.833, 151.747),
      LatLng(-33.762, 151.650),
    ]
  ], fillColor: "#FF0000"),
];

class BatchAddPage extends ExamplePage {
  const BatchAddPage({super.key})
      : super(const Icon(Icons.check_circle), 'Batch add/remove');

  @override
  Widget build(BuildContext context) {
    return const BatchAddBody();
  }
}

class BatchAddBody extends StatefulWidget {
  const BatchAddBody({super.key});

  @override
  State<StatefulWidget> createState() => BatchAddBodyState();
}

class BatchAddBodyState extends State<BatchAddBody> {
  BatchAddBodyState();

  List<Fill> _fills = [];
  List<Circle> _circles = [];
  List<Line> _lines = [];
  List<Symbol> _symbols = [];

  static const LatLng center = LatLng(-33.86711, 151.1947171);

  late MaplibreMapController controller;

  void _onMapCreated(MaplibreMapController controller) {
    this.controller = controller;
  }

  List<LineOptions> makeLinesOptionsForFillOptions(
      Iterable<FillOptions> options) {
    final listOptions = <LineOptions>[];
    for (final option in options) {
      for (final geom in option.geometry!) {
        listOptions.add(LineOptions(geometry: geom, lineColor: "#00FF00"));
      }
    }
    return listOptions;
  }

  List<CircleOptions> makeCircleOptionsForFillOptions(
      Iterable<FillOptions> options) {
    final circleOptions = <CircleOptions>[];
    for (final option in options) {
      // put circles only on the outside
      for (final latLng in option.geometry!.first) {
        circleOptions
            .add(CircleOptions(geometry: latLng, circleColor: "#00FF00"));
      }
    }
    return circleOptions;
  }

  List<SymbolOptions> makeSymbolOptionsForFillOptions(
      Iterable<FillOptions> options) {
    final symbolOptions = <SymbolOptions>[];
    for (final option in options) {
      // put symbols only on the inner most ring if it exists
      if (option.geometry!.length > 1) {
        for (final latLng in option.geometry!.last) {
          symbolOptions
              .add(SymbolOptions(iconImage: 'custom-marker', geometry: latLng));
        }
      }
    }
    return symbolOptions;
  }

  void _add() async {
    if (_fills.isEmpty) {
      _fills = await controller.addFills(fillOptions);
      _lines = await controller
          .addLines(makeLinesOptionsForFillOptions(fillOptions));
      _circles = await controller
          .addCircles(makeCircleOptionsForFillOptions(fillOptions));
      _symbols = await controller
          .addSymbols(makeSymbolOptionsForFillOptions(fillOptions));
    }
  }

  void _remove() {
    controller.removeFills(_fills);
    controller.removeLines(_lines);
    controller.removeCircles(_circles);
    controller.removeSymbols(_symbols);
    _fills.clear();
    _lines.clear();
    _circles.clear();
    _symbols.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: SizedBox(
            height: 200.0,
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: () => addImageFromAsset(controller,
                  "custom-marker", "assets/symbols/custom-marker.png"),
              initialCameraPosition: const CameraPosition(
                target: LatLng(-33.8, 151.511),
                zoom: 8.2,
              ),
              annotationOrder: const [
                AnnotationType.fill,
                AnnotationType.line,
                AnnotationType.circle,
                AnnotationType.symbol,
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        TextButton(
                            onPressed: _add, child: const Text('batch add')),
                        TextButton(
                            onPressed: _remove,
                            child: const Text('batch remove')),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
