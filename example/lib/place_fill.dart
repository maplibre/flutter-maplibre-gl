// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

import 'page.dart';

class PlaceFillPage extends ExamplePage {
  const PlaceFillPage({super.key})
      : super(const Icon(Icons.check_circle), 'Place fill');

  @override
  Widget build(BuildContext context) {
    return const PlaceFillBody();
  }
}

class PlaceFillBody extends StatefulWidget {
  const PlaceFillBody({super.key});

  @override
  State<StatefulWidget> createState() => PlaceFillBodyState();
}

class PlaceFillBodyState extends State<PlaceFillBody> {
  PlaceFillBodyState();

  static const LatLng center = LatLng(-33.86711, 151.1947171);
  final String _fillPatternImage = "assets/fill/cat_silhouette_pattern.png";

  final List<List<LatLng>> _defaultGeometry = [
    [
      const LatLng(-33.719, 151.150),
      const LatLng(-33.858, 151.150),
      const LatLng(-33.866, 151.401),
      const LatLng(-33.747, 151.328),
      const LatLng(-33.719, 151.150),
    ],
    [
      const LatLng(-33.762, 151.250),
      const LatLng(-33.827, 151.250),
      const LatLng(-33.833, 151.347),
      const LatLng(-33.762, 151.250),
    ]
  ];

  MaplibreMapController? controller;
  int _fillCount = 0;
  Fill? _selectedFill;

  void _onMapCreated(MaplibreMapController controller) {
    this.controller = controller;
    controller.onFillTapped.add(_onFillTapped);
    this.controller!.onFeatureDrag.add(_onFeatureDrag);
  }

  void _onFeatureDrag(id,
      {required current,
      required delta,
      required origin,
      required point,
      required eventType}) {
    DragEventType type = eventType;
    switch (type) {
      case DragEventType.start:
        // TODO: Handle this case.
        break;
      case DragEventType.drag:
        // TODO: Handle this case.
        break;
      case DragEventType.end:
        // TODO: Handle this case.
        break;
    }
  }

  void _onStyleLoaded() {
    addImageFromAsset("assetImage", _fillPatternImage);
  }

  /// Adds an asset image to the currently displayed style
  Future<void> addImageFromAsset(String name, String assetName) async {
    final ByteData bytes = await rootBundle.load(assetName);
    final Uint8List list = bytes.buffer.asUint8List();
    return controller!.addImage(name, list);
  }

  @override
  void dispose() {
    controller?.onFillTapped.remove(_onFillTapped);
    super.dispose();
  }

  void _onFillTapped(Fill fill) {
    setState(() {
      _selectedFill = fill;
    });
  }

  void _updateSelectedFill(FillOptions changes) {
    controller!.updateFill(_selectedFill!, changes);
  }

  void _add() {
    controller!.addFill(
      FillOptions(
          geometry: _defaultGeometry,
          fillColor: "#FF0000",
          fillOutlineColor: "#FF0000"),
    );
    setState(() {
      _fillCount += 1;
    });
  }

  void _remove() {
    controller!.removeFill(_selectedFill!);
    setState(() {
      _selectedFill = null;
      _fillCount -= 1;
    });
  }

  void _changePosition() {
    List<List<LatLng>>? geometry = _selectedFill!.options.geometry;

    geometry ??= _defaultGeometry;

    _updateSelectedFill(FillOptions(
        geometry: geometry
            .map((list) => list
                .map(
                    // Move to right with 0.1 degree on longitude
                    (latLng) => LatLng(latLng.latitude, latLng.longitude + 0.1))
                .toList())
            .toList()));
  }

  void _changeDraggable() {
    bool? draggable = _selectedFill!.options.draggable;
    draggable ??= false;
    _updateSelectedFill(
      FillOptions(draggable: !draggable),
    );
  }

  Future<void> _changeFillOpacity() async {
    double? current = _selectedFill!.options.fillOpacity;
    current ??= 1.0;

    _updateSelectedFill(
      FillOptions(fillOpacity: current < 0.1 ? 1.0 : current * 0.75),
    );
  }

  Future<void> _changeFillColor() async {
    String? current = _selectedFill!.options.fillColor;
    current ??= "#FF0000";

    _updateSelectedFill(
      const FillOptions(fillColor: "#FFFF00"),
    );
  }

  Future<void> _changeFillOutlineColor() async {
    String? current = _selectedFill!.options.fillOutlineColor;
    current ??= "#FF0000";

    _updateSelectedFill(
      const FillOptions(fillOutlineColor: "#FFFF00"),
    );
  }

  Future<void> _changeFillPattern() async {
    String? current =
        _selectedFill!.options.fillPattern == null ? "assetImage" : null;
    _updateSelectedFill(
      FillOptions(fillPattern: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 300.0,
            height: 200.0,
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              initialCameraPosition: const CameraPosition(
                target: LatLng(-33.852, 151.211),
                zoom: 7.0,
              ),
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
                          onPressed: (_fillCount == 12) ? null : _add,
                          child: const Text('add'),
                        ),
                        TextButton(
                          onPressed: (_selectedFill == null) ? null : _remove,
                          child: const Text('remove'),
                        ),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        TextButton(
                          onPressed: (_selectedFill == null)
                              ? null
                              : _changeFillOpacity,
                          child: const Text('change fill-opacity'),
                        ),
                        TextButton(
                          onPressed:
                              (_selectedFill == null) ? null : _changeFillColor,
                          child: const Text('change fill-color'),
                        ),
                        TextButton(
                          onPressed: (_selectedFill == null)
                              ? null
                              : _changeFillOutlineColor,
                          child: const Text('change fill-outline-color'),
                        ),
                        TextButton(
                          onPressed: (_selectedFill == null)
                              ? null
                              : _changeFillPattern,
                          child: const Text('change fill-pattern'),
                        ),
                        TextButton(
                          onPressed:
                              (_selectedFill == null) ? null : _changePosition,
                          child: const Text('change position'),
                        ),
                        TextButton(
                          onPressed:
                              (_selectedFill == null) ? null : _changeDraggable,
                          child: const Text('toggle draggable'),
                        ),
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
