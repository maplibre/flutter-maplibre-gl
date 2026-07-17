import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

class TransformRequestExample extends ExamplePage {
  const TransformRequestExample({super.key})
      : super(
          const Icon(Icons.security),
          'Transform Request Headers',
          category: ExampleCategory.advanced,
          needsLocationPermission: false,
        );

  @override
  Widget build(BuildContext context) => const _TransformRequestBody();
}

class _TransformRequestBody extends StatefulWidget {
  const _TransformRequestBody();

  @override
  State<_TransformRequestBody> createState() => _TransformRequestBodyState();
}

class _TransformRequestBodyState extends State<_TransformRequestBody> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  RequestParameters _onTransformRequest(String url, ResourceType resourceType) {
    // We add custom headers for all requests intercepted
    final headers = <String, String>{
      'X-Client-Platform': 'Flutter-Example',
      'X-Example-Header': 'TransformRequestExample',
      'Authorization': 'Bearer mock-jwt-token-12345',
    };

    // Log the request details for visual feedback
    final logMessage = '[${resourceType.name.toUpperCase()}] -> $url\n'
        'Added Headers: $headers';

    // Update log list safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _logs.add(logMessage);
          if (_logs.length > 30) {
            _logs.removeAt(0);
          }
        });
        // Scroll to bottom
        unawaited(Future.delayed(const Duration(milliseconds: 50), () async {
          if (_scrollController.hasClients) {
            await _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        }));
      }
    });

    return RequestParameters(
      url: url,
      headers: headers,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transform Request Example'),
      ),
      body: Column(
        children: [
          // Upper part: Map
          Expanded(
            flex: 3,
            child: MapLibreMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(16.0, 108.0), // Vietnam region center
                zoom: 5.0,
              ),
              styleString: 'https://tiles.sharemap.live/tiles/styles/sharemap.json',
              transformRequest: null,
              trackCameraPosition: true,
            ),
          ),
          // Divider
          Container(
            height: 4,
            color: Theme.of(context).dividerColor,
          ),
          // Lower part: Interception Log Panel
          Expanded(
            flex: 2,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Live Intercepted Network Requests',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => setState(() => _logs.clear()),
                          tooltip: 'Clear Logs',
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'Pan or zoom the map to generate tile requests...',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            itemCount: _logs.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              return SelectableText(
                                _logs[index],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
