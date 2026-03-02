import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating map snapshot functionality
///
/// This example shows how to:
/// - Take a snapshot of the current map view (web only)
/// - Set a custom size for the map before taking a snapshot
/// - Display the captured snapshot in a dialog
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
  bool _canInteractWithMap = false;
  bool _isCapturing = false;
  Size? _customSize;

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() => _canInteractWithMap = true);
  }

  /// Takes a snapshot of the current map view
  Future<void> _takeSnapshot() async {
    if (_mapController == null || !kIsWeb) return;

    setState(() => _isCapturing = true);

    try {
      // Wait for any pending tiles to load
      await _mapController!.waitUntilMapTilesAreLoaded();

      // Take the snapshot
      final dataUrl = await _mapController!.takeWebSnapshot();

      if (!mounted) return;

      // Show the snapshot in a dialog
      await _showSnapshotDialog(dataUrl);
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

  /// Takes a snapshot with a custom map size
  Future<void> _takeCustomSizeSnapshot(Size size) async {
    if (_mapController == null || !kIsWeb) return;

    setState(() => _isCapturing = true);

    try {
      // Define a custom size for the snapshot (e.g., 800x600)
      setState(() => _customSize = size);

      // Temporarily resize the map
      final originalSize = await _mapController!.setWebMapToCustomSize(size);

      // Wait for tiles to load at the new size
      await _mapController!.waitUntilMapTilesAreLoaded();

      // Take the snapshot
      final dataUrl = await _mapController!.takeWebSnapshot();

      // Restore the original size
      await _mapController!.setWebMapToCustomSize(originalSize);

      if (!mounted) return;

      setState(() => _customSize = null);

      // Show the snapshot in a dialog
      await _showSnapshotDialog(dataUrl, size: size);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take snapshot: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _customSize = null;
        });
      }
    }
  }

  Future<void> _showSnapshotDialog(String dataUrl, {Size? size}) async {
    // Parse the base64 data from the data URL
    // Format: data:image/png;base64,<base64data>
    final base64Data = dataUrl.split(',').last;
    final imageBytes = base64Decode(base64Data);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.camera_alt),
            const SizedBox(width: 8),
            Text(size != null
                ? 'Snapshot (${size.width.toInt()}x${size.height.toInt()})'
                : 'Map Snapshot'),
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
    const isWeb = kIsWeb;

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
          if (_customSize != null)
            Positioned(
              top: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Custom size: ${_customSize!.width.toInt()}x${_customSize!.height.toInt()}',
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: !isWeb
          ? Container(
              padding: const EdgeInsets.all(16),
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Map snapshots are only available on web platform.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 16,
                  children: [
                    ExampleButton(
                      label: 'Take Snapshot',
                      icon: Icons.camera_alt,
                      onPressed: _canInteractWithMap && !_isCapturing && isWeb
                          ? _takeSnapshot
                          : null,
                      style: ExampleButtonStyle.filled,
                    ),
                    ExampleButton(
                      label: 'Custom Size (800x600)',
                      icon: Icons.crop,
                      onPressed: _canInteractWithMap && !_isCapturing && isWeb
                          ? () => _takeCustomSizeSnapshot(const Size(800, 600))
                          : null,
                      style: ExampleButtonStyle.tonal,
                    ),
                    ExampleButton(
                      label: 'Custom Size (360x800)',
                      icon: Icons.crop,
                      onPressed: _canInteractWithMap && !_isCapturing && isWeb
                          ? () => _takeCustomSizeSnapshot(const Size(360, 800))
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
