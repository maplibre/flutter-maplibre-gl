// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async'; // ignore: unnecessary_import
import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';

class PlaceSymbolPage extends ExamplePage {
  const PlaceSymbolPage({super.key})
      : super(const Icon(Icons.place), 'Place symbol');

  @override
  Widget build(BuildContext context) {
    return const PlaceSymbolBody();
  }
}

class PlaceSymbolBody extends StatefulWidget {
  const PlaceSymbolBody({super.key});

  @override
  State<StatefulWidget> createState() => PlaceSymbolBodyState();
}

class PlaceSymbolBodyState extends State<PlaceSymbolBody> {
  PlaceSymbolBodyState();

  static const LatLng center = LatLng(-33.86711, 151.1947171);

  MapLibreMapController? controller;
  int _symbolCount = 0;
  Symbol? _selectedSymbol;
  bool _iconAllowOverlap = false;

  void _onMapCreated(MapLibreMapController controller) {
    this.controller = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onStyleLoaded() {
    addImageFromAsset("custom-marker", "assets/symbols/custom-marker.png");
    addImageFromAsset("assetImage", "assets/symbols/custom-icon.png");
    addImageFromUrl(
        "networkImage", Uri.parse("https://via.placeholder.com/50"));
  }

  @override
  void dispose() {
    controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }

  /// Adds an asset image to the currently displayed style
  Future<void> addImageFromAsset(String name, String assetName) async {
    final bytes = await rootBundle.load(assetName);
    final list = bytes.buffer.asUint8List();
    return controller!.addImage(name, list);
  }

  /// Adds a network image to the currently displayed style
  Future<void> addImageFromUrl(String name, Uri uri) async {
    final response = await http.get(uri);
    return controller!.addImage(name, response.bodyBytes);
  }

  void _onSymbolTapped(Symbol symbol) {
    if (_selectedSymbol != null) {
      _updateSelectedSymbol(
        const SymbolOptions(iconSize: 1.0),
      );
    }
    setState(() {
      _selectedSymbol = symbol;
    });
    _updateSelectedSymbol(
      const SymbolOptions(iconSize: 1.4),
    );
  }

  Future<void> _updateSelectedSymbol(SymbolOptions changes) async {
    await controller!.updateSymbol(_selectedSymbol!, changes);
  }

  void _add(String iconImage) {
    final availableNumbers = Iterable<int>.generate(12).toList();
    for (final s in controller!.symbols) {
      availableNumbers.removeWhere((i) => i == s.data!['count']);
    }
    if (availableNumbers.isNotEmpty) {
      controller!.addSymbol(
          _getSymbolOptions(iconImage, availableNumbers.first),
          {'count': availableNumbers.first});
      setState(() {
        _symbolCount += 1;
      });
    }
  }

  SymbolOptions _getSymbolOptions(String iconImage, int symbolCount) {
    final geometry = LatLng(
      center.latitude + sin(symbolCount * pi / 6.0) / 20.0,
      center.longitude + cos(symbolCount * pi / 6.0) / 20.0,
    );
    return iconImage == 'customFont'
        ? SymbolOptions(
            geometry: geometry,
            iconImage: 'custom-marker',
            //'airport-15',
            fontNames: ['DIN Offc Pro Bold', 'Arial Unicode MS Regular'],
            textField: 'Airport',
            textSize: 12.5,
            textOffset: const Offset(0, 0.8),
            textAnchor: 'top',
            textColor: '#000000',
            textHaloBlur: 1,
            textHaloColor: '#ffffff',
            textHaloWidth: 0.8,
          )
        : SymbolOptions(
            geometry: geometry,
            textField: 'Airport',
            textOffset: const Offset(0, 0.8),
            iconImage: iconImage,
          );
  }

  Future<void> _addAll(String iconImage) async {
    final symbolsToAddNumbers = Iterable<int>.generate(12).toList();
    for (final s in controller!.symbols) {
      symbolsToAddNumbers.removeWhere((i) => i == s.data!['count']);
    }

    if (symbolsToAddNumbers.isNotEmpty) {
      final symbolOptionsList = symbolsToAddNumbers
          .map((i) => _getSymbolOptions(iconImage, i))
          .toList();
      controller!.addSymbols(symbolOptionsList,
          symbolsToAddNumbers.map((i) => {'count': i}).toList());

      setState(() {
        _symbolCount += symbolOptionsList.length;
      });
    }
  }

  void _remove() {
    controller!.removeSymbol(_selectedSymbol!);
    setState(() {
      _selectedSymbol = null;
      _symbolCount -= 1;
    });
  }

  void _removeAll() {
    controller!.removeSymbols(controller!.symbols);
    setState(() {
      _selectedSymbol = null;
      _symbolCount = 0;
    });
  }

  void _changePosition() {
    final current = _selectedSymbol!.options.geometry!;
    final offset = Offset(
      center.latitude - current.latitude,
      center.longitude - current.longitude,
    );
    _updateSelectedSymbol(
      SymbolOptions(
        geometry: LatLng(
          center.latitude + offset.dy,
          center.longitude + offset.dx,
        ),
      ),
    );
  }

  void _changeIconOffset() {
    var currentAnchor = _selectedSymbol!.options.iconOffset;
    currentAnchor ??= Offset.zero;
    final newAnchor = Offset(1.0 - currentAnchor.dy, currentAnchor.dx);
    _updateSelectedSymbol(SymbolOptions(iconOffset: newAnchor));
  }

  Future<void> _changeIconAnchor() async {
    var current = _selectedSymbol!.options.iconAnchor;
    if (current == null || current == 'center') {
      current = 'bottom';
    } else {
      current = 'center';
    }
    _updateSelectedSymbol(
      SymbolOptions(iconAnchor: current),
    );
  }

  Future<void> _toggleDraggable() async {
    var draggable = _selectedSymbol!.options.draggable;
    draggable ??= false;

    _updateSelectedSymbol(
      SymbolOptions(draggable: !draggable),
    );
  }

  Future<void> _changeAlpha() async {
    var current = _selectedSymbol!.options.iconOpacity;
    current ??= 1.0;

    _updateSelectedSymbol(
      SymbolOptions(iconOpacity: current < 0.1 ? 1.0 : current * 0.75),
    );
  }

  Future<void> _changeRotation() async {
    var current = _selectedSymbol!.options.iconRotate;
    current ??= 0;
    _updateSelectedSymbol(
      SymbolOptions(iconRotate: current == 330.0 ? 0.0 : current + 30.0),
    );
  }

  Future<void> _toggleVisible() async {
    var current = _selectedSymbol!.options.iconOpacity;
    current ??= 1.0;

    _updateSelectedSymbol(
      SymbolOptions(iconOpacity: current == 0.0 ? 1.0 : 0.0),
    );
  }

  Future<void> _changeZIndex() async {
    var current = _selectedSymbol!.options.zIndex;
    current ??= 0;
    _updateSelectedSymbol(
      SymbolOptions(zIndex: current == 12 ? 0 : current + 1),
    );
  }

  Future<void> _getLatLng() async {
    final latLng = await controller!.getSymbolLatLng(_selectedSymbol!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(latLng.toString()),
      ),
    );
  }

  Future<void> _changeIconOverlap() async {
    setState(() {
      _iconAllowOverlap = !_iconAllowOverlap;
    });
    await controller!.setSymbolIconAllowOverlap(_iconAllowOverlap);
    await controller!.setSymbolTextAllowOverlap(_iconAllowOverlap);
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
            child: MapLibreMap(
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              initialCameraPosition: const CameraPosition(
                target: LatLng(-33.852, 151.211),
                zoom: 11.0,
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
                          child: const Text('add'),
                          onPressed: () => (_symbolCount == 12)
                              ? null
                              : _add("custom-marker"),
                        ),
                        TextButton(
                          child: const Text('add all'),
                          onPressed: () => (_symbolCount == 12)
                              ? null
                              : _addAll("custom-marker"),
                        ),
                        TextButton(
                          child: const Text('add (custom icon)'),
                          onPressed: () => (_symbolCount == 12)
                              ? null
                              : _add("assets/symbols/custom-icon.png"),
                        ),
                        TextButton(
                          onPressed: (_selectedSymbol == null) ? null : _remove,
                          child: const Text('remove'),
                        ),
                        TextButton(
                          onPressed: _changeIconOverlap,
                          child: Text(
                              '${_iconAllowOverlap ? 'disable' : 'enable'} icon overlap'),
                        ),
                        TextButton(
                          onPressed: (_symbolCount == 0) ? null : _removeAll,
                          child: const Text('remove all'),
                        ),
                        TextButton(
                          child: const Text('add (asset image)'),
                          onPressed: () => (_symbolCount == 12)
                              ? null
                              : _add(
                                  "assetImage"), //assetImage added to the style in _onStyleLoaded
                        ),
                        TextButton(
                          child: const Text('add (network image)'),
                          onPressed: () => (_symbolCount == 12)
                              ? null
                              : _add(
                                  "networkImage"), //networkImage added to the style in _onStyleLoaded
                        ),
                        TextButton(
                          child: const Text('add (custom font)'),
                          onPressed: () =>
                              (_symbolCount == 12) ? null : _add("customFont"),
                        )
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        TextButton(
                          onPressed:
                              (_selectedSymbol == null) ? null : _changeAlpha,
                          child: const Text('change alpha'),
                        ),
                        TextButton(
                          onPressed: (_selectedSymbol == null)
                              ? null
                              : _changeIconOffset,
                          child: const Text('change icon offset'),
                        ),
                        TextButton(
                          onPressed: (_selectedSymbol == null)
                              ? null
                              : _changeIconAnchor,
                          child: const Text('change icon anchor'),
                        ),
                        TextButton(
                          onPressed: (_selectedSymbol == null)
                              ? null
                              : _toggleDraggable,
                          child: const Text('toggle draggable'),
                        ),
                        TextButton(
                          onPressed: (_selectedSymbol == null)
                              ? null
                              : _changePosition,
                          child: const Text('change position'),
                        ),
                        TextButton(
                          onPressed: (_selectedSymbol == null)
                              ? null
                              : _changeRotation,
                          child: const Text('change rotation'),
                        ),
                        TextButton(
                          onPressed:
                              (_selectedSymbol == null) ? null : _toggleVisible,
                          child: const Text('toggle visible'),
                        ),
                        TextButton(
                          onPressed:
                              (_selectedSymbol == null) ? null : _changeZIndex,
                          child: const Text('change zIndex'),
                        ),
                        TextButton(
                          onPressed:
                              (_selectedSymbol == null) ? null : _getLatLng,
                          child: const Text('get current LatLng'),
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
