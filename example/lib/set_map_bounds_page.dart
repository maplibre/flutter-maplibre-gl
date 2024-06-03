// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';
import 'package:maplibre_gl_example/main.dart';

class SetMapBoundsPage extends StatefulWidget {
  const SetMapBoundsPage({super.key});

  @override
  State<SetMapBoundsPage> createState() => _SetMapBoundsPageState();
}

class _SetMapBoundsPageState extends State<SetMapBoundsPage> {
  late MaplibreMapController mapController;

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      page: ExamplePage.setMapBounds,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () async {
                    await mapController.setCameraBounds(
                      west: 5.98865807458,
                      south: 47.3024876979,
                      east: 15.0169958839,
                      north: 54.983104153,
                      padding: 25,
                    );
                  },
                  child: const Text('Set bounds to Germany'),
                ),
                TextButton(
                  onPressed: () async {
                    await mapController.setCameraBounds(
                      west: -18,
                      south: -40,
                      east: 54,
                      north: 40,
                      padding: 25,
                    );
                  },
                  child: const Text('Set bounds to Africa'),
                ),
              ],
            ),
          ),
          Expanded(
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition:
                  const CameraPosition(target: LatLng(0.0, 0.0)),
            ),
          ),
        ],
      ),
    );
  }
}
