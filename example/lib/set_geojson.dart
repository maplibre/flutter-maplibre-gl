// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

import 'page.dart';

class SetGeoJsonPage extends ExamplePage {
  SetGeoJsonPage()
      : super(const Icon(Icons.map), 'Set the Geojson Example');

  @override
  Widget build(BuildContext context) {
    return const SetGeoJson();
  }
}

class SetGeoJson extends StatefulWidget {
  const SetGeoJson();
  @override
  State createState() => SetGeoJsonState();
}

class SetGeoJsonState extends State<SetGeoJson> {
  late MaplibreMapController mapController;

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
            width: 300.0,
            height: 200.0,
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition:
              const CameraPosition(target: LatLng(0.0, 0.0)),
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            await mapController.setGeoJson(_geoJsonString!);
          },
          child: const Text('Set one GeoJson'),
        ),
        TextButton(
          onPressed: () async {
            await mapController.setGeoJson(_geoJsonString!);
          },
          child: const Text('Set another GeoJson'),
        ),
      ],
    );
  }
}
