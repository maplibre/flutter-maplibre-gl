// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import 'package:maplibre_gl_example/util.dart';

import 'page.dart';

class QueryFeaturesPage extends ExamplePage {
  QueryFeaturesPage()
      : super(const Icon(Icons.map), 'Tap on Map to query features');

  @override
  Widget build(BuildContext context) {
    return const QueryFeatures();
  }
}

class QueryFeatures extends StatefulWidget {
  const QueryFeatures();
  @override
  State createState() => QueryFeaturesState();
}

class QueryFeaturesState extends State<QueryFeatures> {
  late MaplibreMapController mapController;
  static final LatLng center = const LatLng(-33.86711, 151.1947171);

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: SizedBox(
            height: 500.0,
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: 5.0,
              ),
              onMapClick: (point, latLng) async {
                print(
                    "Map click: ${point.x},${point.y}   ${latLng.latitude}/${latLng.longitude}");

                var rect = Rect.fromLTRB(point.x, point.y, point.x, point.y)
                    .inflate(50.0);

                List features = await mapController.queryRenderedFeaturesInRect(
                    rect, [], null);

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('QueryRenderedFeatures: ' +
                        features.length.toString())));
              },
            ),
          ),
        ),
      ],
    );
  }
}
