import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

class GetMapInfoPage extends ExamplePage {
  const GetMapInfoPage({super.key})
    : super(
        const Icon(Icons.info),
        'Get map state',
        category: ExampleCategory.basics,
      );

  @override
  Widget build(BuildContext context) => const _GetMapInfoBody();
}

class _GetMapInfoBody extends StatefulWidget {
  const _GetMapInfoBody();

  @override
  State<_GetMapInfoBody> createState() => _GetMapInfoBodyState();
}

class _GetMapInfoBodyState extends State<_GetMapInfoBody> {
  MapLibreMapController? _controller;
  String _displayData = '';
  bool _isLoading = false;

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _displaySources() async {
    if (_controller == null) return;

    setState(() => _isLoading = true);

    try {
      final sources = await _controller!.getSourceIds();
      setState(() {
        _displayData = 'Sources:\n${sources.map((e) => '• $e').join('\n')}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _displayData = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _displayLayers() async {
    if (_controller == null) return;

    setState(() => _isLoading = true);

    try {
      final layers = (await _controller!.getLayerIds()).cast<String>();
      setState(() {
        _displayData = 'Layers:\n${layers.map((e) => '• $e').join('\n')}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _displayData = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Reads the full style-spec properties of the first layer on the map,
  /// demonstrating getLayerProperties (#513).
  Future<void> _displayFirstLayerProperties() async {
    if (_controller == null) return;
    setState(() => _isLoading = true);
    try {
      final ids = (await _controller!.getLayerIds()).cast<String>();
      final props =
          ids.isEmpty ? null : await _controller!.getLayerProperties(ids.first);
      setState(() {
        _displayData =
            props == null
                ? 'No layers found.'
                : 'Layer "${ids.first}":\n'
                    '${const JsonEncoder.withIndent('  ').convert(props)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _displayData = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Reads the full style-spec properties of the first source on the map,
  /// demonstrating getSourceProperties (#513).
  Future<void> _displayFirstSourceProperties() async {
    if (_controller == null) return;
    setState(() => _isLoading = true);
    try {
      final ids = await _controller!.getSourceIds();
      final props =
          ids.isEmpty
              ? null
              : await _controller!.getSourceProperties(ids.first);
      setState(() {
        _displayData =
            props == null
                ? 'No sources found.'
                : 'Source "${ids.first}":\n'
                    '${const JsonEncoder.withIndent('  ').convert(props)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _displayData = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;

    return MapExampleScaffold(
      map: MapLibreMap(
        onMapCreated: _onMapCreated,
        styleString: ExampleConstants.demoMapStyle,
        initialCameraPosition: ExampleConstants.defaultCameraPosition,
      ),
      controls: [
        if (!hasController)
          const InfoCard(
            title: 'Waiting for map',
            subtitle: 'Map is initializing...',
            icon: Icons.hourglass_empty,
          ),
        if (hasController) ...[
          const SizedBox(height: 8),
          ControlGroup(
            title: 'Map Information',
            vertical: false,
            children: [
              ExampleButton(
                label: 'Get Layers',
                onPressed: hasController ? _displayLayers : null,
                icon: Icons.layers,
                style: ExampleButtonStyle.filled,
              ),
              ExampleButton(
                label: 'Get Sources',
                onPressed: hasController ? _displaySources : null,
                icon: Icons.source,
                style: ExampleButtonStyle.filled,
              ),
              ExampleButton(
                label: 'First Layer Props',
                onPressed: hasController ? _displayFirstLayerProperties : null,
                icon: Icons.data_object,
                style: ExampleButtonStyle.outlined,
              ),
              ExampleButton(
                label: 'First Source Props',
                onPressed: hasController ? _displayFirstSourceProperties : null,
                icon: Icons.data_object,
                style: ExampleButtonStyle.outlined,
              ),
            ],
          ),
          if (_isLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_displayData.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Results',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _displayData,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
