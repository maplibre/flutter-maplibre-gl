import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating the globe projection, 3D terrain and the sky, three
/// style root objects MapLibre Native does not implement yet.
class GlobeTerrainSkyPage extends ExamplePage {
  const GlobeTerrainSkyPage({super.key})
    : super(
        const Icon(Icons.public),
        'Globe, terrain and sky',
        category: ExampleCategory.advanced,
      );

  @override
  Widget build(BuildContext context) => const _GlobeTerrainSkyBody();
}

class _GlobeTerrainSkyBody extends StatefulWidget {
  const _GlobeTerrainSkyBody();

  @override
  State<_GlobeTerrainSkyBody> createState() => _GlobeTerrainSkyBodyState();
}

class _GlobeTerrainSkyBodyState extends State<_GlobeTerrainSkyBody> {
  static const _demSourceId = 'terrarium-dem';

  /// Where the page opens: the whole globe.
  static const _overviewCamera = CameraPosition(
    target: LatLng(46.5, 8.0),
    zoom: 3,
  );

  /// Where the terrain toggle flies to: the Matterhorn, tilted, where the
  /// relief is unmistakable. From straight above, 3D terrain shows nothing.
  static const _alpsCamera = CameraPosition(
    target: LatLng(45.9766, 7.6585),
    zoom: 11.5,
    tilt: 68,
    bearing: 130,
  );

  MapLibreMapController? _controller;
  bool _globe = true;
  bool _terrain = false;
  bool _sky = true;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.addSource(
      _demSourceId,
      const RasterDemSourceProperties(
        tiles: [
          'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
        ],
        minzoom: 0,
        maxzoom: 15,
        tileSize: 256,
        encoding: 'terrarium',
        attribution:
            '<a href="https://registry.opendata.aws/terrain-tiles/">Elevation data © AWS Terrain Tiles</a>',
      ),
    );
    await _applySky();
    await _applyProjection();
    await _applyTerrain();
  }

  Future<void> _applyProjection() async {
    await _controller?.setProjection(_globe ? 'globe' : 'mercator');
  }

  Future<void> _applySky() async {
    // The atmosphere halo fades out between zoom 10 and 12, so the tilted
    // terrain view gets a clean sky-to-horizon gradient instead of a halo.
    await _controller?.setSky(
      _sky
          ? const SkyProperties(
            skyColor: '#199EF3',
            horizonColor: '#ffffff',
            fogColor: '#ffffff',
            fogGroundBlend: 0.5,
            horizonFogBlend: 0.5,
            skyHorizonBlend: 0.6,
            atmosphereBlend: [
              Expressions.interpolate,
              ['linear'],
              [Expressions.zoom],
              0,
              1,
              10,
              1,
              12,
              0,
            ],
          )
          : const SkyProperties(atmosphereBlend: 0),
    );
  }

  Future<void> _applyTerrain({bool flyToShowIt = false}) async {
    await _controller?.setTerrain(
      _terrain
          ? const TerrainProperties(source: _demSourceId, exaggeration: 1.5)
          : null,
    );
    if (flyToShowIt) {
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          _terrain ? _alpsCamera : _overviewCamera,
        ),
        duration: const Duration(milliseconds: 2500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The globe projection, 3D terrain and the sky are only available '
            'on web. MapLibre Native does not implement them yet, so on '
            'Android and iOS setProjection, setTerrain and setSky throw an '
            'UnsupportedError.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: _overviewCamera,
      ),
      controls: [
        ControlGroup(
          title: 'Style root objects',
          children: [
            SwitchListTile(
              title: const Text('Globe projection'),
              subtitle: const Text(
                'The earth as a sphere instead of a flat '
                'mercator plane, best seen zoomed out',
              ),
              value: _globe,
              onChanged: (value) async {
                setState(() => _globe = value);
                await _applyProjection();
              },
            ),
            SwitchListTile(
              title: const Text('Sky and atmosphere'),
              subtitle: const Text(
                'The halo around the globe, and the sky '
                'above the horizon in the tilted terrain view',
              ),
              value: _sky,
              onChanged: (value) async {
                setState(() => _sky = value);
                await _applySky();
              },
            ),
            SwitchListTile(
              title: const Text('3D terrain'),
              subtitle: const Text(
                'Raises the map by real elevation and '
                'flies to the Matterhorn, where the relief shows',
              ),
              value: _terrain,
              onChanged: (value) async {
                setState(() => _terrain = value);
                await _applyTerrain(flyToShowIt: true);
              },
            ),
          ],
        ),
      ],
    );
  }
}
