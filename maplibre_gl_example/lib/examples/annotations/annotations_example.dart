import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Unified example for all annotation types (symbols, circles, fills, lines)
class AnnotationsExample extends ExamplePage {
  const AnnotationsExample({super.key})
      : super(
          const Icon(Icons.place),
          'Annotations',
          category: ExampleCategory.annotations,
        );

  @override
  Widget build(BuildContext context) => const _AnnotationsBody();
}

enum AnnotationType { symbol, circle, fill, line }

class _AnnotationsBody extends StatefulWidget {
  const _AnnotationsBody();

  @override
  State<_AnnotationsBody> createState() => _AnnotationsBodyState();
}

class _AnnotationsBodyState extends State<_AnnotationsBody> {
  MapLibreMapController? _controller;
  AnnotationType _currentType = AnnotationType.symbol;

  final Map<String, Symbol> _symbols = {};
  final Map<String, Circle> _circles = {};
  final Map<String, Fill> _fills = {};
  final Map<String, Line> _lines = {};

  int _counter = 0;
  String? _lastTappedAnnotation;

  void _onMapCreated(MapLibreMapController controller) {
    controller.onSymbolTapped.add(_onSymbolTapped);
    controller.onCircleTapped.add(_onCircleTapped);
    controller.onFillTapped.add(_onFillTapped);
    controller.onLineTapped.add(_onLineTapped);

    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await addImageFromAsset(
      _controller!,
      "custom-marker",
      "assets/symbols/custom-marker.png",
    );
  }

  void _onSymbolTapped(Symbol symbol) {
    final symbolId = _symbols.entries
        .firstWhere((entry) => entry.value == symbol,
            orElse: () => MapEntry('', symbol))
        .key;
    setState(() => _lastTappedAnnotation = 'Selected: $symbolId');
  }

  void _onCircleTapped(Circle circle) {
    final circleId = _circles.entries
        .firstWhere((entry) => entry.value == circle,
            orElse: () => MapEntry('', circle))
        .key;
    setState(() => _lastTappedAnnotation = 'Selected: $circleId');
  }

  void _onFillTapped(Fill fill) {
    final fillId = _fills.entries
        .firstWhere((entry) => entry.value == fill,
            orElse: () => MapEntry('', fill))
        .key;
    setState(() => _lastTappedAnnotation = 'Fill: $fillId');
  }

  void _onLineTapped(Line line) {
    final lineId = _lines.entries
        .firstWhere((entry) => entry.value == line,
            orElse: () => MapEntry('', line))
        .key;
    setState(() => _lastTappedAnnotation = 'Line: $lineId');
  }

  Future<void> _addAnnotation() async {
    if (_controller == null) return;

    final random = Random();
    const center = ExampleConstants.sydneyCenter;

    // Use different spread patterns for different annotation types
    // to prevent overlapping and ensure visibility
    double latOffset;
    double lngOffset;
    // Base Y offset for vertical separation
    double baseLatOffset;

    switch (_currentType) {
      case AnnotationType.symbol:
        baseLatOffset = 0.25;
        latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
        lngOffset = (random.nextDouble() - 0.5) * 0.25;
      case AnnotationType.circle:
        baseLatOffset = 0.08;
        latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
        lngOffset = (random.nextDouble() - 0.5) * 0.3;
      case AnnotationType.fill:
        baseLatOffset = -0.08;
        latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
        lngOffset = (random.nextDouble() - 0.5) * 0.35;
      case AnnotationType.line:
        baseLatOffset = -0.25;
        latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
        lngOffset = (random.nextDouble() - 0.5) * 0.35;
    }

    final lat = center.latitude + latOffset;
    final lng = center.longitude + lngOffset;
    final position = LatLng(lat, lng);

    _counter++;

    switch (_currentType) {
      case AnnotationType.symbol:
        final symbol = await _controller!.addSymbol(
          SymbolOptions(
            geometry: position,
            iconImage: 'custom-marker',
            iconSize: 2.0,
            textField: 'Symbol $_counter',
            textOffset: const Offset(0, 2),
          ),
        );
        setState(() => _symbols['symbol_$_counter'] = symbol);
        await _controller?.setSymbolIconAllowOverlap(true);
        await _controller?.setSymbolTextAllowOverlap(true);

      case AnnotationType.circle:
        final circle = await _controller!.addCircle(
          CircleOptions(
            geometry: position,
            circleRadius: 18.0,
            circleColor: _randomColor(),
            circleOpacity: 0.7,
          ),
        );
        setState(() => _circles['circle_$_counter'] = circle);

      case AnnotationType.fill:
        final fill = await _controller!.addFill(
          FillOptions(
            geometry: _generatePolygon(position),
            fillColor: _randomColor(),
            fillOpacity: 0.6,
            fillOutlineColor: '#000000',
          ),
        );
        setState(() => _fills['fill_$_counter'] = fill);

      case AnnotationType.line:
        final line = await _controller!.addLine(
          LineOptions(
            geometry: _generateLineString(position),
            lineColor: _randomColor(),
            lineWidth: 8.0,
            lineOpacity: 0.9,
          ),
        );
        setState(() => _lines['line_$_counter'] = line);
    }
  }

  Future<void> _clearAnnotations() async {
    if (_controller == null) return;

    switch (_currentType) {
      case AnnotationType.symbol:
        if (_symbols.isNotEmpty) {
          await _controller!.removeSymbols(_symbols.values.toList());
          setState(() => _symbols.clear());
        }
      case AnnotationType.circle:
        if (_circles.isNotEmpty) {
          await _controller!.removeCircles(_circles.values.toList());
          setState(() => _circles.clear());
        }
      case AnnotationType.fill:
        if (_fills.isNotEmpty) {
          await _controller!.removeFills(_fills.values.toList());
          setState(() => _fills.clear());
        }
      case AnnotationType.line:
        if (_lines.isNotEmpty) {
          await _controller!.removeLines(_lines.values.toList());
          setState(() => _lines.clear());
        }
    }
  }

  Future<void> _batchAdd({int count = 5}) async {
    if (_controller == null) return;

    final random = Random();
    const center = ExampleConstants.sydneyCenter;

    for (var i = 0; i < count; i++) {
      double latOffset;
      double lngOffset;
      double baseLatOffset;

      switch (_currentType) {
        case AnnotationType.symbol:
          baseLatOffset = 0.25;
          latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
          lngOffset = (random.nextDouble() - 0.5) * 0.25;
        case AnnotationType.circle:
          baseLatOffset = 0.08;
          latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
          lngOffset = (random.nextDouble() - 0.5) * 0.3;
        case AnnotationType.fill:
          baseLatOffset = -0.08;
          latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
          lngOffset = (random.nextDouble() - 0.5) * 0.35;
        case AnnotationType.line:
          baseLatOffset = -0.25;
          latOffset = baseLatOffset + (random.nextDouble() - 0.5) * 0.06;
          lngOffset = (random.nextDouble() - 0.5) * 0.35;
      }

      final lat = center.latitude + latOffset;
      final lng = center.longitude + lngOffset;
      final position = LatLng(lat, lng);

      _counter++;

      switch (_currentType) {
        case AnnotationType.symbol:
          final symbol = await _controller!.addSymbol(
            SymbolOptions(
              geometry: position,
              iconImage: 'custom-marker',
              iconSize: 2.0,
              textField: 'Symbol $_counter',
              textOffset: const Offset(0, 2),
            ),
          );
          _symbols['symbol_$_counter'] = symbol;

        case AnnotationType.circle:
          final circle = await _controller!.addCircle(
            CircleOptions(
              geometry: position,
              circleRadius: 18.0,
              circleColor: _randomColor(),
              circleOpacity: 0.7,
            ),
          );
          _circles['circle_$_counter'] = circle;

        case AnnotationType.fill:
          final fill = await _controller!.addFill(
            FillOptions(
              geometry: _generatePolygon(position),
              fillColor: _randomColor(),
              fillOpacity: 0.6,
              fillOutlineColor: '#000000',
            ),
          );
          _fills['fill_$_counter'] = fill;

        case AnnotationType.line:
          final line = await _controller!.addLine(
            LineOptions(
              geometry: _generateLineString(position),
              lineColor: _randomColor(),
              lineWidth: 8.0,
              lineOpacity: 0.9,
            ),
          );
          _lines['line_$_counter'] = line;
      }
    }

    if (_currentType == AnnotationType.symbol) {
      await _controller?.setSymbolIconAllowOverlap(true);
      await _controller?.setSymbolTextAllowOverlap(true);
    }

    setState(() {});
  }

  Future<void> _batchRemove({int count = 5}) async {
    if (_controller == null) return;

    switch (_currentType) {
      case AnnotationType.symbol:
        if (_symbols.isEmpty) return;
        final toRemove =
            _symbols.values.take(count.clamp(0, _symbols.length)).toList();
        final keysToRemove = _symbols.entries
            .where((e) => toRemove.contains(e.value))
            .map((e) => e.key)
            .toList();
        await _controller!.removeSymbols(toRemove);
        setState(() {
          keysToRemove.forEach(_symbols.remove);
        });

      case AnnotationType.circle:
        if (_circles.isEmpty) return;
        final toRemove =
            _circles.values.take(count.clamp(0, _circles.length)).toList();
        final keysToRemove = _circles.entries
            .where((e) => toRemove.contains(e.value))
            .map((e) => e.key)
            .toList();
        await _controller!.removeCircles(toRemove);
        setState(() {
          keysToRemove.forEach(_circles.remove);
        });

      case AnnotationType.fill:
        if (_fills.isEmpty) return;
        final toRemove =
            _fills.values.take(count.clamp(0, _fills.length)).toList();
        final keysToRemove = _fills.entries
            .where((e) => toRemove.contains(e.value))
            .map((e) => e.key)
            .toList();
        await _controller!.removeFills(toRemove);
        setState(() {
          keysToRemove.forEach(_fills.remove);
        });

      case AnnotationType.line:
        if (_lines.isEmpty) return;
        final toRemove =
            _lines.values.take(count.clamp(0, _lines.length)).toList();
        final keysToRemove = _lines.entries
            .where((e) => toRemove.contains(e.value))
            .map((e) => e.key)
            .toList();
        await _controller!.removeLines(toRemove);
        setState(() {
          keysToRemove.forEach(_lines.remove);
        });
    }
  }

  String _randomColor() {
    final colors = [
      '#FF6B6B', // Red
      '#4ECDC4', // Teal
      '#45B7D1', // Blue
      '#FFA07A', // Orange
      '#98D8C8', // Green
      '#F7DC6F', // Yellow
      '#BB8FCE', // Purple
    ];
    return colors[Random().nextInt(colors.length)];
  }

  List<List<LatLng>> _generatePolygon(LatLng center) {
    // Make polygon larger and more visible
    const offset = 0.06;
    return [
      [
        LatLng(center.latitude + offset, center.longitude - offset),
        LatLng(center.latitude + offset, center.longitude + offset),
        LatLng(center.latitude - offset, center.longitude + offset),
        LatLng(center.latitude - offset, center.longitude - offset),
        LatLng(center.latitude + offset, center.longitude - offset),
      ]
    ];
  }

  List<LatLng> _generateLineString(LatLng center) {
    // Make line longer and more visible with more points for a curved appearance
    const offset = 0.08;
    return [
      LatLng(center.latitude - offset, center.longitude - offset),
      LatLng(center.latitude - offset * 0.3, center.longitude),
      LatLng(center.latitude + offset * 0.3, center.longitude + offset * 0.5),
      LatLng(center.latitude + offset, center.longitude + offset),
    ];
  }

  int _getCurrentCount() {
    switch (_currentType) {
      case AnnotationType.symbol:
        return _symbols.length;
      case AnnotationType.circle:
        return _circles.length;
      case AnnotationType.fill:
        return _fills.length;
      case AnnotationType.line:
        return _lines.length;
    }
  }

  int _getTotalCount() {
    return _symbols.length + _circles.length + _fills.length + _lines.length;
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;
    final count = _getCurrentCount();
    final totalCount = _getTotalCount();

    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 8,
        ),
        trackCameraPosition: true,
      ),
      controls: [
        InfoCard(
          title: _lastTappedAnnotation ??
              '${_currentType.name.capitalize()}s on Map',
          subtitle:
              '$count annotation${count == 1 ? "" : "s"}.${_lastTappedAnnotation == null ? " Tap an annotation to select." : ""}',
          icon: _lastTappedAnnotation != null
              ? Icons.touch_app
              : Icons.info_outline,
        ),

        // Type Selector
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annotation Type',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                ExampleSegmentedButton<AnnotationType>(
                  segments: const [
                    ExampleSegment(
                      value: AnnotationType.symbol,
                      label: 'Symbol',
                      icon: Icons.place,
                    ),
                    ExampleSegment(
                      value: AnnotationType.circle,
                      label: 'Circle',
                      icon: Icons.circle,
                    ),
                    ExampleSegment(
                      value: AnnotationType.fill,
                      label: 'Fill',
                      icon: Icons.square,
                    ),
                    ExampleSegment(
                      value: AnnotationType.line,
                      label: 'Line',
                      icon: Icons.show_chart,
                    ),
                  ],
                  selected: _currentType,
                  onSelectionChanged: (type) {
                    setState(() => _currentType = type);
                  },
                ),
              ],
            ),
          ),
        ),

        ControlGroup(
          title: 'Actions',
          children: [
            ExampleButton(
              label: 'Add ${_currentType.name.capitalize()}',
              icon: Icons.add,
              onPressed: hasController ? _addAnnotation : null,
            ),
            ExampleButton(
              label: 'Clear ${_currentType.name.capitalize()}s',
              icon: Icons.delete_sweep,
              onPressed: hasController && count > 0 ? _clearAnnotations : null,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),

        ControlGroup(
          title: 'Batch Actions',
          children: [
            ExampleButton(
              label: 'Add 10',
              icon: Icons.add_box,
              onPressed: hasController ? () => _batchAdd(count: 10) : null,
            ),
            ExampleButton(
              label: 'Remove 10',
              icon: Icons.remove_circle_outline,
              onPressed: hasController && count >= 10
                  ? () => _batchRemove(count: 10)
                  : null,
              style: ExampleButtonStyle.outlined,
            ),
            ExampleButton(
              label: 'Clear all annotations',
              icon: Icons.clear,
              onPressed: hasController && totalCount > 0
                  ? () async {
                      _lastTappedAnnotation = null;
                      await _controller!.clearSymbols();
                      await _controller!.clearCircles();
                      await _controller!.clearFills();
                      await _controller!.clearLines();
                      setState(() {
                        _symbols.clear();
                        _circles.clear();
                        _fills.clear();
                        _lines.clear();
                      });
                    }
                  : null,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),
      ],
    );
  }
}
