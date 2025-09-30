import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb; // added
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';

import 'page.dart';

class LocalStylePage extends ExamplePage {
  const LocalStylePage({super.key})
      : super(const Icon(Icons.map), 'Local style');

  @override
  Widget build(BuildContext context) {
    return const LocalStyle();
  }
}

class LocalStyle extends StatefulWidget {
  const LocalStyle({super.key});

  @override
  State createState() => LocalStyleState();
}

class LocalStyleState extends State<LocalStyle> {
  MapLibreMapController? mapController;
  String? styleAbsoluteFilePath;
  String? _inMemoryStyle; // web fallback

  static const String _styleJSON = MapLibreStyles.demo;

  @override
  initState() {
    super.initState();

    if (kIsWeb) {
      // On web we can't use path_provider, just keep the JSON in memory
      _inMemoryStyle = _styleJSON;
      // Trigger rebuild so map loads immediately
      scheduleMicrotask(() => setState(() {}));
    } else {
      unawaited(_prepareLocalStyleFile());
    }
  }

  Future<void> _prepareLocalStyleFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final documentDir = dir.path;
    final stylesDir = '$documentDir/styles';

    await Directory(stylesDir).create(recursive: true);

    final styleFile = File('$stylesDir/style.json');
    await styleFile.writeAsString(_styleJSON);

    if (mounted) {
      setState(() {
        styleAbsoluteFilePath = styleFile.path;
      });
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;

    // Adding style to the map with some delay to watch the setStyle method working
    Future.delayed(const Duration(milliseconds: 250), () async {
      if (kIsWeb) {
        if (_inMemoryStyle != null) {
          await mapController?.setStyle(_inMemoryStyle!);
        }
      } else {
        if (styleAbsoluteFilePath != null) {
          await mapController?.setStyle(styleAbsoluteFilePath!);
        }
      }

      log('Style loaded from local file ${await mapController?.getStyle()}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        kIsWeb ? _inMemoryStyle != null : styleAbsoluteFilePath != null;
    if (!ready) {
      return const Scaffold(
        body: Center(child: Text('Preparing local style...')),
      );
    }

    return Scaffold(
      body: MapLibreMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0)),
        onStyleLoadedCallback: onStyleLoadedCallback,
      ),
    );
  }

  Future<void> onStyleLoadedCallback() async {
    log('Style loaded from local file ${await mapController?.getStyle()}');
  }
}
