// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';

class MapSnapshotPage extends ExamplePage {
  const MapSnapshotPage({super.key})
      : super(const Icon(Icons.camera_alt), 'Map Snapshot');

  @override
  Widget build(BuildContext context) {
    return const MapSnapshotBody();
  }
}

class MapSnapshotBody extends StatefulWidget {
  const MapSnapshotBody({super.key});

  @override
  State<MapSnapshotBody> createState() => _MapSnapshotBodyState();
}

class _MapSnapshotBodyState extends State<MapSnapshotBody> {
  Uint8List? _snapshotImage;
  bool _isLoading = false;
  String? _error;
  String? _currentCity;
  double _currentZoom = 3.0;
  bool _showMarkers = true;

  Future<Uint8List> _createMarkerIcon(String label, [double pixelRatio = 1.0]) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 64.0 * pixelRatio;
    
    // Draw emoji only with DPR consideration
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 48 * pixelRatio,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2),
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _createFrenchFlagIcon([double pixelRatio = 1.0]) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 64.0 * pixelRatio;
    final flagWidth = 51.2 * pixelRatio;
    final flagHeight = 38.4 * pixelRatio;
    final stripeWidth = 17.066666666666666 * pixelRatio;
    
    // Calculate flag position (centered)
    final flagX = (size - flagWidth) / 2;
    final flagY = (size - flagHeight) / 2;
    
    // Draw French flag (blue, white, red vertical stripes)
    // Blue stripe
    final bluePaint = Paint()..color = const Color(0xFF0055A4);
    canvas.drawRect(Rect.fromLTWH(flagX, flagY, stripeWidth, flagHeight), bluePaint);
    
    // White stripe
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(flagX + stripeWidth, flagY, stripeWidth, flagHeight), whitePaint);
    
    // Red stripe
    final redPaint = Paint()..color = const Color(0xFFEF4135);
    canvas.drawRect(Rect.fromLTWH(flagX + stripeWidth * 2, flagY, stripeWidth, flagHeight), redPaint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * pixelRatio;
    canvas.drawRect(Rect.fromLTWH(flagX, flagY, flagWidth, flagHeight), borderPaint);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  Future<void> _takeSnapshot() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _snapshotImage = null;
      _currentCity = null;
    });

    try {
      // Define random camera positions for different cities
      final cities = [
        {'name': 'Beijing', 'lat': 39.9042, 'lng': 116.4074},
        {'name': 'San Francisco', 'lat': 37.7749, 'lng': -122.4194},
        {'name': 'London', 'lat': 51.5074, 'lng': -0.1278},
        {'name': 'Sydney', 'lat': -33.8688, 'lng': 151.2093},
      ];
      
      // Pick a random city
      final randomCity = cities[DateTime.now().millisecond % cities.length];
      
      final cameraPosition = CameraPosition(
        target: LatLng(randomCity['lat'] as double, randomCity['lng'] as double),
        zoom: _currentZoom,
      );

      // Take the snapshot with DPR consideration
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      
      // Create markers if enabled
      List<MapMarker>? markers;
      if (_showMarkers) {
        final cityName = randomCity['name'] as String;

        markers = [
          MapMarker(
            position: LatLng(randomCity['lat'] as double, randomCity['lng'] as double),
            iconData: await _createMarkerIcon('📍', pixelRatio),
            iconSize: 36.0,
            label: cityName,
          ),
          MapMarker(
            position: LatLng(48.8566, 2.3522),
            iconData: await _createFrenchFlagIcon(pixelRatio),
            iconSize: 24.0,
            label: 'Paris',
          ),
        ];
      }
      final imageData = await startMapSnapshot(
        width: (400 * pixelRatio).toInt(),
        height: (300 * pixelRatio).toInt(),
        styleUrl: 'https://demotiles.maplibre.org/style.json',
        cameraPosition: cameraPosition,
        markers: markers,
      );

      setState(() {
        _snapshotImage = imageData;
        _currentCity = randomCity['name'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _takeSnapshot,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Take Map Snapshot'),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zoom Level: ${_currentZoom.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _currentZoom,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    onChanged: (value) {
                      setState(() {
                        _currentZoom = value;
                      });
                    },
                  ),
                  const Text(
                    'Zoom: 1.0 (World) - 20.0 (Streets)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Show Markers'),
                      const SizedBox(width: 8),
                      Switch(
                        value: _showMarkers,
                        onChanged: (value) {
                          setState(() {
                            _showMarkers = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Generating snapshot...'),
        ],
      );
    }

    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_snapshotImage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Map Snapshot - $_currentCity',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Image.memory(
            _snapshotImage!,
            width: 400,
            height: 300,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            'Snapshot of $_currentCity with zoom level ${_currentZoom.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 48, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'Press the button above to take a map snapshot',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
