import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

const _style = 'https://tiles.openfreemap.org/styles/liberty';

const _languages = [
  _Language('English', 'en', '🇬🇧'),
  _Language('Italiano', 'it', '🇮🇹'),
  _Language('Deutsch', 'de', '🇩🇪'),
  _Language('Français', 'fr', '🇫🇷'),
  _Language('中文', 'zh', '🇨🇳'),
  _Language('日本語', 'ja', '🇯🇵'),
  _Language('عربي', 'ar', '🇸🇦'),
];

class _Language {
  final String label;
  final String code;
  final String flag;

  const _Language(this.label, this.code, this.flag);
}

class MapLanguageExample extends ExamplePage {
  const MapLanguageExample({super.key})
    : super(
        const Icon(Icons.translate),
        'Map Language',
        needsLocationPermission: false,
        category: ExampleCategory.advanced,
      );

  @override
  Widget build(BuildContext context) => const _MapLanguageBody();
}

class _MapLanguageBody extends StatefulWidget {
  const _MapLanguageBody();

  @override
  State<_MapLanguageBody> createState() => _MapLanguageBodyState();
}

class _MapLanguageBodyState extends State<_MapLanguageBody> {
  MapLibreMapController? _controller;
  _Language _selected = _languages.first;
  bool _ready = false;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  void _onStyleLoaded() {
    setState(() => _ready = true);
  }

  Future<void> _setLanguage(_Language lang) async {
    if (_controller == null) return;
    setState(() => _selected = lang);
    try {
      await _controller!.setMapLanguage(lang.code);
    } catch (e) {
      dev.log('setMapLanguage error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.london,
          zoom: 5,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        styleString: _style,
      ),
      controls: [
        ControlGroup(
          title: 'Language',
          vertical: true,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _languages.map((lang) {
                    final isSelected = lang.code == _selected.code;
                    return FilterChip(
                      label: Text('${lang.flag} ${lang.label}'),
                      selected: isSelected,
                      onSelected: _ready ? (_) => _setLanguage(lang) : null,
                    );
                  }).toList(),
            ),
          ],
        ),
      ],
    );
  }
}
