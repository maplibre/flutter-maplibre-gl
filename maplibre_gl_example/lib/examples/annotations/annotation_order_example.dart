import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';
import '../../util.dart';

/// Example demonstrating annotation rendering order control
class AnnotationOrderExample extends ExamplePage {
  const AnnotationOrderExample({super.key})
      : super(
          const Icon(Icons.layers),
          'Annotation Order',
          category: ExampleCategory.annotations,
        );

  @override
  Widget build(BuildContext context) => const _AnnotationOrderBody();
}

class _AnnotationOrderBody extends StatefulWidget {
  const _AnnotationOrderBody();

  @override
  State<_AnnotationOrderBody> createState() => _AnnotationOrderBodyState();
}

class _AnnotationOrderBodyState extends State<_AnnotationOrderBody> {
  MapLibreMapController? _controller;

  // Default order: bottom to top
  final List<AnnotationType> _annotationOrder = [
    AnnotationType.fill,
    AnnotationType.line,
    AnnotationType.circle,
    AnnotationType.symbol,
  ];

  final LatLng _center = const LatLng(36.580664, 32.5563837);

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    if (_controller == null) return;

    await addImageFromAsset(
      _controller!,
      "custom-marker",
      "assets/symbols/custom-marker.png",
    );

    await _controller!.addSymbol(
      const SymbolOptions(
        geometry: LatLng(35.5, 31.8),
        iconImage: "custom-marker",
        iconSize: 2.5,
        iconOpacity: 1.0,
      ),
    );

    await _controller!.addLine(
      const LineOptions(
        lineColor: "#ff0000",
        lineWidth: 8.0,
        lineOpacity: 1.0,
        geometry: [
          LatLng(37.5, 31.0),
          LatLng(36.5, 31.3),
          LatLng(36.0, 31.5),
          LatLng(35.5, 31.8),
          LatLng(35.0, 32.0),
          LatLng(34.5, 31.5),
        ],
      ),
    );

    await _controller!.addFill(
      const FillOptions(
        fillColor: "#00aa88",
        fillOpacity: 1.0,
        fillOutlineColor: "#008866",
        geometry: [
          [
            LatLng(35.3649902, 32.0593003),
            LatLng(34.9475098, 31.1187944),
            LatLng(36.7108154, 30.7040582),
            LatLng(37.6995850, 33.6512083),
            LatLng(35.3814697, 32.0546447),
          ]
        ],
      ),
    );

    await _controller!.addCircle(
      const CircleOptions(
        geometry: LatLng(36.0, 31.5),
        circleRadius: 13.0,
        circleColor: "#4169E1",
        circleOpacity: 1.0,
      ),
    );
  }

  void _recreateMap() {
    setState(() {
      _controller = null;
    });
  }

  IconData _getIconForType(AnnotationType type) {
    switch (type) {
      case AnnotationType.fill:
        return Icons.square;
      case AnnotationType.line:
        return Icons.show_chart;
      case AnnotationType.symbol:
        return Icons.place;
      case AnnotationType.circle:
        return Icons.circle;
    }
  }

  String _getNameForType(AnnotationType type) {
    switch (type) {
      case AnnotationType.fill:
        return 'Fill';
      case AnnotationType.line:
        return 'Line';
      case AnnotationType.symbol:
        return 'Symbol';
      case AnnotationType.circle:
        return 'Circle';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      mapHeightRatio: 0.4,
      map: MapLibreMap(
        key: ValueKey(_annotationOrder.toString()),
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 5.5,
        ),
        annotationOrder: _annotationOrder,
      ),
      controls: [
        const InfoCard(
          title: 'Drag to reorder Annotations',
          subtitle: 'Change rendering order from bottom to top',
          icon: Icons.layers,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.drag_indicator,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rendering order (Last on Top)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _annotationOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = _annotationOrder.removeAt(oldIndex);
                      _annotationOrder.insert(newIndex, item);
                      _recreateMap();
                    });
                  },
                  itemBuilder: (context, index) {
                    final type = _annotationOrder[index];
                    return Container(
                      key: ValueKey(type),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 2,
                        child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                _getIconForType(type),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                          title: Text(
                            _getNameForType(type),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          trailing: Icon(
                            Icons.drag_handle,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
