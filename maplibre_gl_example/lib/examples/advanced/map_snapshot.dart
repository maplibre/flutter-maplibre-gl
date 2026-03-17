import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Cross-platform map snapshot example.
///
/// Uses [MapLibreMapController.takeSnapshot] to capture the current map view
/// as PNG bytes. Works on Android, iOS, and Web with the same code.
class MapSnapshotPage extends ExamplePage {
  const MapSnapshotPage({super.key})
      : super(
          const Icon(Icons.camera_alt),
          'Map Snapshot',
          category: ExampleCategory.advanced,
        );

  @override
  Widget build(BuildContext context) => const _MapSnapshotBody();
}

class _MapSnapshotBody extends StatefulWidget {
  const _MapSnapshotBody();

  @override
  State<_MapSnapshotBody> createState() => _MapSnapshotBodyState();
}

class _MapSnapshotBodyState extends State<_MapSnapshotBody> {
  MapLibreMapController? _mapController;
  bool _canInteract = false;
  bool _isCapturing = false;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() => _canInteract = true);
  }

  Future<void> _takeSnapshot({int? width, int? height}) async {
    if (_mapController == null) return;

    setState(() => _isCapturing = true);

    try {
      final imageBytes = await _mapController!.takeSnapshot(
        width: width,
        height: height,
      );

      if (!mounted) return;

      await _showSnapshotDialog(imageBytes, width: width, height: height);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take snapshot: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _showSnapshotDialog(
    Uint8List imageBytes, {
    int? width,
    int? height,
  }) async {
    final sizeLabel =
        width != null && height != null ? '(${width}x$height)' : '';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.camera_alt),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Map Snapshot $sizeLabel',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Image size: ${(imageBytes.length / 1024).toStringAsFixed(1)} KB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _canInteract && !_isCapturing;

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: ExampleConstants.demoMapStyle,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: ExampleConstants.londonCameraPosition,
            trackCameraPosition: true,
            compassEnabled: true,
          ),
          if (_isCapturing)
            const ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Capturing snapshot...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ExampleButton(
                label: 'Snapshot',
                icon: Icons.camera_alt,
                onPressed: enabled ? () => _takeSnapshot() : null,
                style: ExampleButtonStyle.filled,
              ),
              ExampleButton(
                label: '800x600',
                icon: Icons.crop,
                onPressed: enabled
                    ? () => _takeSnapshot(width: 800, height: 600)
                    : null,
                style: ExampleButtonStyle.tonal,
              ),
              ExampleButton(
                label: '360x800',
                icon: Icons.crop,
                onPressed: enabled
                    ? () => _takeSnapshot(width: 360, height: 800)
                    : null,
                style: ExampleButtonStyle.tonal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
