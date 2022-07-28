// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import 'package:maplibre_gl_example/util.dart';

import 'page.dart';

class SetLayerVisiblePage extends ExamplePage {
  SetLayerVisiblePage()
      : super(const Icon(Icons.map), 'Change visibility of a layer');

  @override
  Widget build(BuildContext context) {
    return const SetLayerVisible();
  }
}

class SetLayerVisible extends StatefulWidget {
  const SetLayerVisible();
  @override
  State createState() => SetLayerVisibleState();
}

class SetLayerVisibleState extends State<SetLayerVisible> {
  late MaplibreMapController mapController;
  static final LatLng center = const LatLng(-33.86711, 151.1947171);

  void _onMapCreated(MaplibreMapController controller) async {
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
            height: 400.0,
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoadedCallback,
              initialCameraPosition: CameraPosition(
              target: center,
              zoom: 11.0,
            ),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            mapController.setLayerVisibility(['circles'], false);
          },
          child: const Text('Make circles layer invisible'),
        ),
        TextButton(
          onPressed: () {
            mapController.setLayerVisibility(['circles'], true);
          },
          child: const Text('Make circles layer visible'),
        ),
      ],
    );
  }

  void _onStyleLoadedCallback() async {
    await mapController.addSource('fills', GeojsonSourceProperties(data: _fills));
    await mapController.addCircleLayer(
      'fills',
      'circles',
      CircleLayerProperties(
        circleRadius: 40,
        circleColor: Colors.red.toHexStringRGB(),
      ),
    );

  }
}

final _fills = {
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": 0,
      "properties": <String, dynamic>{'id': 0},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [151.178099204457737, -33.901517742631846],
            [151.179025547977773, -33.872845324482071],
            [151.147000529140399, -33.868230472039514],
            [151.150838238009328, -33.883172899638311],
            [151.14223647675135, -33.894158309528244],
            [151.155999294764086, -33.904812805307806],
            [151.178099204457737, -33.901517742631846]
          ],
          [
            [151.162657925954278, -33.879168932438581],
            [151.155323416087612, -33.890737666431583],
            [151.173659690754278, -33.897637567778119],
            [151.162657925954278, -33.879168932438581]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "id": 1,
      "properties": <String, dynamic>{'id': 1},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [151.18735077583878, -33.891143558434102],
            [151.197374605989864, -33.878357032551868],
            [151.213021560372084, -33.886475683791488],
            [151.204953599518745, -33.899463918807818],
            [151.18735077583878, -33.891143558434102]
          ]
        ]
      }
    }
  ]
};
