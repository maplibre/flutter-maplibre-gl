import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Comprehensive camera control example with animated and instant movements
class CameraControlsExample extends ExamplePage {
  const CameraControlsExample({super.key})
      : super(
          const Icon(Icons.videocam),
          'Camera Controls',
          category: ExampleCategory.camera,
        );

  @override
  Widget build(BuildContext context) => const _CameraControlsBody();
}

class _CameraControlsBody extends StatefulWidget {
  const _CameraControlsBody();

  @override
  State<_CameraControlsBody> createState() => _CameraControlsBodyState();
}

class _CameraControlsBodyState extends State<_CameraControlsBody> {
  MapLibreMapController? _controller;
  bool _isAnimated = true;
  CameraPosition? _currentPosition;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  void _onCameraIdle() {
    final position = _controller?.cameraPosition;
    if (mounted && position != null) {
      setState(() => _currentPosition = position);
    }
  }

  Future<void> _moveCamera(CameraUpdate update) async {
    if (_controller == null) return;

    if (_isAnimated) {
      await _controller!.animateCamera(update,
          duration: ExampleConstants.cameraAnimationDuration);
    } else {
      await _controller!.moveCamera(update);
    }
  }

  Future<void> _zoomIn() => _moveCamera(CameraUpdate.zoomIn());
  Future<void> _zoomOut() => _moveCamera(CameraUpdate.zoomOut());

  Future<void> _tiltUp() async {
    final current = _currentPosition?.tilt ?? 0;
    await _moveCamera(CameraUpdate.tiltTo(current + 15));
  }

  Future<void> _tiltDown() async {
    final current = _currentPosition?.tilt ?? 0;
    await _moveCamera(CameraUpdate.tiltTo((current - 15).clamp(0, 60)));
  }

  Future<void> _rotateLeft() async {
    final current = _currentPosition?.bearing ?? 0;
    await _moveCamera(CameraUpdate.bearingTo(current - 30));
  }

  Future<void> _rotateRight() async {
    final current = _currentPosition?.bearing ?? 0;
    await _moveCamera(CameraUpdate.bearingTo(current + 30));
  }

  Future<void> _resetCamera() => _moveCamera(
        CameraUpdate.newCameraPosition(ExampleConstants.defaultCameraPosition),
      );

  Future<void> _goToSydney() => _moveCamera(
        CameraUpdate.newCameraPosition(ExampleConstants.sydneyCameraPosition),
      );
  Future<void> _goToSanFrancisco() => _moveCamera(
        CameraUpdate.newCameraPosition(
            ExampleConstants.sanFranciscoCameraPosition),
      );

  Future<void> _goToLondon() => _moveCamera(
        CameraUpdate.newCameraPosition(
          ExampleConstants.londonCameraPosition,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;
    final zoom = _currentPosition?.zoom.toStringAsFixed(1) ?? '--';
    final tilt = _currentPosition?.tilt.toStringAsFixed(0) ?? '--';
    final bearing = _currentPosition?.bearing.toStringAsFixed(0) ?? '--';

    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onCameraIdle: _onCameraIdle,
        initialCameraPosition: ExampleConstants.defaultCameraPosition,
        trackCameraPosition: true,
        myLocationEnabled: true,
        compassEnabled: true,
      ),
      controls: [
        // Animation Mode Toggle
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isAnimated ? Icons.play_circle : Icons.skip_next,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Animation',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Switch(
                  value: _isAnimated,
                  onChanged: (value) => setState(() => _isAnimated = value),
                ),
              ],
            ),
          ),
        ),

        // Camera Info
        InfoCard(
          title: 'Camera Position',
          subtitle: 'Zoom: $zoom | Tilt: $tilt° | Bearing: $bearing°',
          icon: Icons.info_outline,
        ),

        const SizedBox(height: 8),

        // Zoom Controls
        ControlGroup(
          title: 'Zoom',
          children: [
            ExampleButton(
              label: 'Zoom In',
              icon: Icons.add,
              onPressed: hasController ? _zoomIn : null,
            ),
            ExampleButton(
              label: 'Zoom Out',
              icon: Icons.remove,
              onPressed: hasController ? _zoomOut : null,
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Tilt Controls
        ControlGroup(
          title: 'Tilt (Pitch)',
          children: [
            ExampleButton(
              label: 'Tilt Up',
              icon: Icons.arrow_upward,
              onPressed: hasController ? _tiltUp : null,
            ),
            ExampleButton(
              label: 'Tilt Down',
              icon: Icons.arrow_downward,
              onPressed: hasController ? _tiltDown : null,
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Rotation Controls
        ControlGroup(
          title: 'Rotation (Bearing)',
          children: [
            ExampleButton(
              label: 'Rotate Left',
              icon: Icons.rotate_left,
              onPressed: hasController ? _rotateLeft : null,
            ),
            ExampleButton(
              label: 'Rotate Right',
              icon: Icons.rotate_right,
              onPressed: hasController ? _rotateRight : null,
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Location Presets
        ControlGroup(
          title: 'Go To Location',
          children: [
            ExampleButton(
              label: 'Null Island',
              icon: Icons.place,
              onPressed: hasController ? _resetCamera : null,
              style: ExampleButtonStyle.tonal,
            ),
            ExampleButton(
              label: 'Sydney',
              icon: Icons.place,
              onPressed: hasController ? _goToSydney : null,
              style: ExampleButtonStyle.tonal,
            ),
            ExampleButton(
              label: 'San Francisco',
              icon: Icons.place,
              onPressed: hasController ? _goToSanFrancisco : null,
              style: ExampleButtonStyle.tonal,
            ),
            ExampleButton(
              label: 'London',
              icon: Icons.place,
              onPressed: hasController ? _goToLondon : null,
              style: ExampleButtonStyle.tonal,
            ),
          ],
        ),
      ],
    );
  }
}
