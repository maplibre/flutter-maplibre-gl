// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';

class GivenBoundsPage extends ExamplePage {
  const GivenBoundsPage({super.key})
      : super(const Icon(Icons.map_sharp), 'Changing given bounds');

  @override
  Widget build(BuildContext context) {
    return const GivenBounds();
  }
}

class GivenBounds extends StatefulWidget {
  const GivenBounds({super.key});

  @override
  State createState() => GivenBoundsState();
}

class GivenBoundsState extends State<GivenBounds> {
  late MapLibreMapController mapController;

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Column(
      children: [
        SizedBox(
          width: width,
          height: height * 0.5,
          child: MapLibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
                const CameraPosition(target: LatLng(0.0, 0.0)),
          ),
        ),
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
    );
  }
}
