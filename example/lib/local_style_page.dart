import 'dart:io';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';
import 'package:maplibre_gl_example/main.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:path_provider/path_provider.dart';

class LocalStylePage extends StatefulWidget {
  const LocalStylePage({super.key});

  @override
  State<LocalStylePage> createState() => _LocalStylePageState();
}

class _LocalStylePageState extends State<LocalStylePage> {
  MaplibreMapController? mapController;
  String? styleAbsoluteFilePath;

  @override
  initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((dir) async {
      String documentDir = dir.path;
      String stylesDir = '$documentDir/styles';
      String styleJSON = MaplibreStyles.demo;

      await Directory(stylesDir).create(recursive: true);

      File styleFile = File('$stylesDir/style.json');

      await styleFile.writeAsString(styleJSON);

      setState(() {
        styleAbsoluteFilePath = styleFile.path;
      });
    });
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final styleAbsoluteFilePath = this.styleAbsoluteFilePath;

    if (styleAbsoluteFilePath == null) {
      return const ExampleScaffold(
        page: ExamplePage.localStyle,
        body: Center(child: Text('Creating local style file...')),
      );
    }

    return ExampleScaffold(
      page: ExamplePage.localStyle,
      body: MaplibreMap(
        styleString: styleAbsoluteFilePath,
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0)),
        onStyleLoadedCallback: onStyleLoadedCallback,
      ),
    );
  }

  void onStyleLoadedCallback() {}
}
