import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/main.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';

class LocalizedMapPage extends StatefulWidget {
  const LocalizedMapPage({super.key});

  @override
  State<LocalizedMapPage> createState() => _LocalizedMapPageState();
}

class _LocalizedMapPageState extends State<LocalizedMapPage> {
  final _mapReadyCompleter = Completer<MaplibreMapController>();

  var _mapLanguage = "en";

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      page: ExamplePage.localized,
      body: Column(
        children: [
          DropdownButton<String>(
            value: _mapLanguage,
            icon: const Icon(Icons.arrow_drop_down),
            elevation: 16,
            onChanged: (value) {
              if (value == null) return;

              setState(() => _mapLanguage = value);
              _setMapLanguage();
            },
            items: ["en", "de", "es", "pl"]
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          Expanded(
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition:
                  const CameraPosition(target: LatLng(0.0, 0.0)),
              onStyleLoadedCallback: _onStyleLoadedCallback,
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MaplibreMapController controller) {
    _mapReadyCompleter.complete(controller);
  }

  void _onStyleLoadedCallback() {
    _setMapLanguage();
  }

  Future<void> _setMapLanguage() async {
    final controller = await _mapReadyCompleter.future;
    controller.setMapLanguage(_mapLanguage);
  }
}
