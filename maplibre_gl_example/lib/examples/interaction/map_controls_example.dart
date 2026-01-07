import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating map UI controls and settings
class MapControlsExample extends ExamplePage {
  const MapControlsExample({super.key})
      : super(
          const Icon(Icons.settings),
          'Map Controls',
          category: ExampleCategory.interaction,
        );

  @override
  Widget build(BuildContext context) => const _MapControlsBody();
}

class _MapControlsBody extends StatefulWidget {
  const _MapControlsBody();

  @override
  State<_MapControlsBody> createState() => _MapControlsBodyState();
}

class _MapControlsBodyState extends State<_MapControlsBody> {
  MapLibreMapController? _controller;

  // UI Settings
  bool _compassEnabled = true;
  CompassViewPosition _compassPosition = CompassViewPosition.topRight;

  bool _logoEnabled = true;
  LogoViewPosition _logoPosition = LogoViewPosition.bottomLeft;

  AttributionButtonPosition _attributionPosition =
      AttributionButtonPosition.bottomRight;

  // Current Map State
  CameraPosition? _currentPosition;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.addListener(_onMapChanged);
  }

  void _onMapChanged() {
    final position = _controller?.cameraPosition;
    if (mounted && position != null) {
      setState(() => _currentPosition = position);
    }
  }

  Future<void> _updateCompass(bool enabled) async {
    setState(() => _compassEnabled = enabled);
  }

  void _cycleCompassPosition() {
    const positions = CompassViewPosition.values;
    final currentIndex = positions.indexOf(_compassPosition);
    setState(() {
      _compassPosition = positions[(currentIndex + 1) % positions.length];
    });
  }

  Future<void> _updateLogo(bool enabled) async {
    setState(() => _logoEnabled = enabled);
  }

  void _cycleLogoPosition() {
    const positions = LogoViewPosition.values;
    final currentIndex = positions.indexOf(_logoPosition);
    setState(() {
      _logoPosition = positions[(currentIndex + 1) % positions.length];
    });
  }

  void _cycleAttributionPosition() {
    const positions = AttributionButtonPosition.values;
    final currentIndex = positions.indexOf(_attributionPosition);
    setState(() {
      _attributionPosition = positions[(currentIndex + 1) % positions.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final zoom = _currentPosition?.zoom.toStringAsFixed(1) ?? '--';
    final lat = _currentPosition?.target.latitude.toStringAsFixed(4) ?? '--';
    final lng = _currentPosition?.target.longitude.toStringAsFixed(4) ?? '--';

    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        initialCameraPosition: ExampleConstants.defaultCameraPosition,
        trackCameraPosition: true,
        compassEnabled: _compassEnabled,
        compassViewPosition: _compassPosition,
        logoEnabled: _logoEnabled,
        logoViewPosition: _logoPosition,
        attributionButtonPosition: _attributionPosition,
      ),
      controls: [
        InfoCard(
          title: 'Camera Info',
          subtitle: 'Zoom: $zoom\nLat: $lat, Lng: $lng',
          icon: Icons.camera,
        ),
        _buildControlCard(
          title: 'Logo',
          icon: Icons.image,
          enabled: _logoEnabled,
          position: _logoPosition.name.capitalize(),
          onToggle: _updateLogo,
          onChangePosition: _cycleLogoPosition,
        ),
        _buildControlCard(
          title: 'Attribution',
          icon: Icons.info_outline,
          enabled: true,
          position: _attributionPosition.name.capitalize(),
          onChangePosition: _cycleAttributionPosition,
          showToggle: false,
        ),
        _buildControlCard(
          title: 'Compass',
          icon: Icons.explore,
          enabled: _compassEnabled,
          position: _compassPosition.name.capitalize(),
          onToggle: _updateCompass,
          onChangePosition: _cycleCompassPosition,
        ),
      ],
    );
  }

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required bool enabled,
    required String position,
    required VoidCallback onChangePosition,
    void Function(bool)? onToggle,
    bool showToggle = true,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (showToggle && onToggle != null)
                  Switch(
                    value: enabled,
                    onChanged: onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Position',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        position,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: (!showToggle || enabled) ? onChangePosition : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onMapChanged);
    super.dispose();
  }
}
