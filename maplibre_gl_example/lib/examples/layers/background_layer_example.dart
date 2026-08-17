import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating the background layer, which paints the whole map
/// behind every other layer and has no source.
class BackgroundLayerExample extends ExamplePage {
  const BackgroundLayerExample({super.key})
    : super(
        const Icon(Icons.format_color_fill),
        'Background Layer',
        category: ExampleCategory.layers,
      );

  @override
  Widget build(BuildContext context) => const _BackgroundLayerBody();
}

class _BackgroundLayerBody extends StatefulWidget {
  const _BackgroundLayerBody();

  @override
  State<_BackgroundLayerBody> createState() => _BackgroundLayerBodyState();
}

class _BackgroundLayerBodyState extends State<_BackgroundLayerBody> {
  static const _layerId = 'background_layer';

  MapLibreMapController? _controller;
  Color _backgroundColor = const Color(0xFF1B3A5C);
  double _backgroundOpacity = 1.0;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    // The style's own layers draw on top, so the background only shows where
    // they leave the map bare. Anchor it above the style's own background,
    // which is the first layer of most styles: below that one it would be
    // covered by an opaque colour and nothing would show.
    final layerIds = await _controller!.getLayerIds();
    await _controller!.addBackgroundLayer(
      _layerId,
      BackgroundLayerProperties(
        backgroundColor: _backgroundColor.toHexStringRGB(),
        backgroundOpacity: _backgroundOpacity,
      ),
      belowLayerId: layerIds.length < 2 ? null : layerIds[1] as String,
    );
    setState(() {});
  }

  Future<void> _updateLayer() async {
    await _controller?.setLayerProperties(
      _layerId,
      BackgroundLayerProperties(
        backgroundColor: _backgroundColor.toHexStringRGB(),
        backgroundOpacity: _backgroundOpacity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 4,
        ),
      ),
      controls: [
        ControlGroup(
          title: 'Background',
          children: [
            ListTile(
              title: const Text('Color'),
              trailing: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onTap: () async {
                final selected = await ColorPickerModal.show(
                  context: context,
                  title: 'Select Background Color',
                  currentColor: _backgroundColor,
                );
                if (selected == null) return;
                setState(() => _backgroundColor = selected);
                await _updateLayer();
              },
            ),
            ListTile(
              title: Text(
                'Opacity: ${(_backgroundOpacity * 100).toStringAsFixed(0)}%',
              ),
              subtitle: Slider(
                value: _backgroundOpacity,
                divisions: 20,
                onChanged: (value) async {
                  setState(() => _backgroundOpacity = value);
                  await _updateLayer();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
