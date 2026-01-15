part of '../maplibre_gl.dart';

/// Manages a homogeneous set of [Annotation]s (e.g. symbols, lines, fills) by
/// owning their backing style source(s)/layer(s) and performing efficient
/// batched updates.
///
/// The [initialize] method must be called before [AnnotationManager] instance
/// can be used. Once [AnnotationManager] is initialized, the [isInitialized]
/// getter will return true.
///
/// An [AnnotationManager] keeps an internal mapping from annotation id to its
/// model object and mirrors the collection into one or more GeoJSON sources;
/// each source is bound to a style layer whose visual properties come from
/// [allLayerProperties].
///
/// When [enableInteraction] is true, drag events are listened to and the
/// underlying annotation is translated & re-set.
abstract class AnnotationManager<T extends Annotation> {
  final MapLibreMapController controller;

  bool _isInitializing = false;
  bool _isInitialized = false;
  final _idToAnnotation = <String, T>{};
  final _idToLayerIndex = <String, int>{};

  /// Base identifier of the manager. Use [layerIds] for concrete layer ids.
  final String id;

  /// Tracks whether the manager and its layers were initialized.
  bool get isInitialized => _isInitialized;

  List<String> get layerIds =>
      [for (int i = 0; i < allLayerProperties.length; i++) _makeLayerId(i)];

  /// If false, the manager disables user interaction (e.g. dragging) for
  /// its annotations.
  final bool enableInteraction;

  /// Layer property definitions (one per backing style layer). Override in
  /// subclasses to specify visual styling for data-driven attributes.
  List<LayerProperties> get allLayerProperties;

  /// Optional function used to select which layer/source a given annotation
  /// should live in (e.g. pattern vs non-pattern lines). If null, a single
  /// layer/source is used.
  final int Function(T)? selectLayer;

  /// Returns the annotation with the given [id], or null if not found.
  T? byId(String id) => _idToAnnotation[id];

  /// Current set of managed annotations.
  Set<T> get annotations => _idToAnnotation.values.toSet();

  AnnotationManager(
    this.controller, {
    this.selectLayer,
    required this.enableInteraction,
  }) : id = getRandomString();

  @mustCallSuper
  Future<void> initialize() async {
    if (_isInitializing || _isInitialized || controller.isDisposed) {
      return;
    }

    // Mark initialization process start, so that it cannot be entered again
    _isInitializing = true;

    try {
      for (var i = 0; i < allLayerProperties.length; i++) {
        final layerId = _makeLayerId(i);

        await controller.addGeoJsonSource(
          layerId,
          buildFeatureCollection([]),
          promoteId: "id",
        );
        await controller.addLayer(
          layerId,
          layerId,
          allLayerProperties[i],
          enableInteraction: enableInteraction,
        );
      }

      controller.onFeatureDrag.add(_onDrag);

      // Mark as initialized
      _isInitialized = true;
    } finally {
      // Mark initialization process end
      _isInitializing = false;
    }
  }

  /// Rebuilds all backing style layers (e.g. after overlap settings changed).
  Future<void> _rebuildLayers() async {
    if (controller.isDisposed) return;

    for (var i = 0; i < allLayerProperties.length; i++) {
      final layerId = _makeLayerId(i);
      await controller.removeLayer(layerId);
      await controller.addLayer(layerId, layerId, allLayerProperties[i],
          enableInteraction: enableInteraction);
    }
  }

  String _makeLayerId(int layerIndex) => "${id}_$layerIndex";

  Future<void> _setAll() async {
    if (controller.isDisposed) return;

    if (selectLayer != null) {
      final featureBuckets = [for (final _ in allLayerProperties) <T>[]];

      for (final annotation in _idToAnnotation.values) {
        final layerIndex = selectLayer!(annotation);
        _idToLayerIndex[annotation.id] = layerIndex;
        featureBuckets[layerIndex].add(annotation);
      }

      for (var i = 0; i < featureBuckets.length; i++) {
        await controller.setGeoJsonSource(
            _makeLayerId(i),
            buildFeatureCollection(
                [for (final l in featureBuckets[i]) l.toGeoJson()]));
      }
    } else {
      await controller.setGeoJsonSource(
          _makeLayerId(0),
          buildFeatureCollection(
              [for (final l in _idToAnnotation.values) l.toGeoJson()]));
    }
  }

  /// Adds multiple annotations (faster than adding one-by-one).
  Future<void> addAll(Iterable<T> annotations) async {
    for (final a in annotations) {
      _idToAnnotation[a.id] = a;
    }
    await _setAll();
  }

  /// Adds a single annotation.
  Future<void> add(T annotation) async {
    _idToAnnotation[annotation.id] = annotation;
    await _setAll();
  }

  /// Removes multiple annotations.
  Future<void> removeAll(Iterable<T> annotations) async {
    for (final a in annotations) {
      _idToAnnotation.remove(a.id);
    }
    await _setAll();
  }

  /// Removes a single annotation.
  Future<void> remove(T annotation) async {
    _idToAnnotation.remove(annotation.id);
    await _setAll();
  }

  /// Removes all annotations.
  Future<void> clear() async {
    _idToAnnotation.clear();
    await _setAll();
  }

  /// Fully dispose resources (layers & sources). Manager is unusable after.
  Future<void> dispose() async {
    if (controller.isDisposed) return;
    _idToAnnotation.clear();

    await _setAll();
    for (var i = 0; i < allLayerProperties.length; i++) {
      await controller.removeLayer(_makeLayerId(i));
      await controller.removeSource(_makeLayerId(i));
    }
  }

  Future<void> _onDrag(
    Point<double> point,
    LatLng origin,
    LatLng current,
    LatLng delta,
    String id,
    Annotation? annotation,
    DragEventType eventType,
  ) async {
    if (annotation is T) {
      annotation.translate(delta);
      await set(annotation);
    }
  }

  /// Updates (re-sets) an existing annotation quickly by only replacing its
  /// underlying GeoJSON feature if it remains on the same logical layer.
  Future<void> set(T annotation) async {
    assert(_idToAnnotation.containsKey(annotation.id),
        "you can only set existing annotations");
    _idToAnnotation[annotation.id] = annotation;
    final oldLayerIndex = _idToLayerIndex[annotation.id];
    final layerIndex = selectLayer != null ? selectLayer!(annotation) : 0;
    if (oldLayerIndex != layerIndex) {
      // Layer changed; must rewrite all sources.
      await _setAll();
    } else {
      await controller.setGeoJsonFeature(
          _makeLayerId(layerIndex), annotation.toGeoJson());
    }
  }
}

class LineManager extends AnnotationManager<Line> {
  LineManager(
    super.controller, {
    super.enableInteraction = true,
  }) : super(
          selectLayer: (Line line) => line.options.linePattern == null ? 0 : 1,
        );

  static const _baseProperties = LineLayerProperties(
    lineJoin: [Expressions.get, 'lineJoin'],
    lineOpacity: [Expressions.get, 'lineOpacity'],
    lineColor: [Expressions.get, 'lineColor'],
    lineWidth: [Expressions.get, 'lineWidth'],
    lineGapWidth: [Expressions.get, 'lineGapWidth'],
    lineOffset: [Expressions.get, 'lineOffset'],
    lineBlur: [Expressions.get, 'lineBlur'],
  );

  @override
  List<LayerProperties> get allLayerProperties => [
        _baseProperties,
        _baseProperties.copyWith(const LineLayerProperties(
            linePattern: [Expressions.get, 'linePattern'])),
      ];
}

class FillManager extends AnnotationManager<Fill> {
  FillManager(
    super.controller, {
    super.enableInteraction = true,
  }) : super(
          selectLayer: (Fill fill) => fill.options.fillPattern == null ? 0 : 1,
        );

  @override
  List<LayerProperties> get allLayerProperties => const [
        FillLayerProperties(
          fillOpacity: [Expressions.get, 'fillOpacity'],
          fillColor: [Expressions.get, 'fillColor'],
          fillOutlineColor: [Expressions.get, 'fillOutlineColor'],
        ),
        FillLayerProperties(
          fillOpacity: [Expressions.get, 'fillOpacity'],
          fillColor: [Expressions.get, 'fillColor'],
          fillOutlineColor: [Expressions.get, 'fillOutlineColor'],
          fillPattern: [Expressions.get, 'fillPattern'],
        )
      ];
}

class CircleManager extends AnnotationManager<Circle> {
  CircleManager(
    super.controller, {
    super.enableInteraction = true,
  });

  @override
  List<LayerProperties> get allLayerProperties => const [
        CircleLayerProperties(
          circleRadius: [Expressions.get, 'circleRadius'],
          circleColor: [Expressions.get, 'circleColor'],
          circleBlur: [Expressions.get, 'circleBlur'],
          circleOpacity: [Expressions.get, 'circleOpacity'],
          circleStrokeWidth: [Expressions.get, 'circleStrokeWidth'],
          circleStrokeColor: [Expressions.get, 'circleStrokeColor'],
          circleStrokeOpacity: [Expressions.get, 'circleStrokeOpacity'],
        )
      ];
}

class SymbolManager extends AnnotationManager<Symbol> {
  SymbolManager(
    super.controller, {
    bool iconAllowOverlap = false,
    bool textAllowOverlap = false,
    bool iconIgnorePlacement = false,
    bool textIgnorePlacement = false,
    super.enableInteraction = true,
  })  : _iconAllowOverlap = iconAllowOverlap,
        _textAllowOverlap = textAllowOverlap,
        _iconIgnorePlacement = iconIgnorePlacement,
        _textIgnorePlacement = textIgnorePlacement;

  bool _iconAllowOverlap;
  bool _textAllowOverlap;
  bool _iconIgnorePlacement;
  bool _textIgnorePlacement;

  /// If true, the icon will be visible even if it collides with other previously drawn symbols.
  Future<void> setIconAllowOverlap(bool value) async {
    if (value == _iconAllowOverlap) return;

    _iconAllowOverlap = value;
    await _rebuildLayers();
  }

  /// If true, other symbols can be visible even if they collide with the icon.
  Future<void> setTextAllowOverlap(bool value) async {
    if (value == _textAllowOverlap) return;

    _textAllowOverlap = value;
    await _rebuildLayers();
  }

  /// If true, the text will be visible even if it collides with other previously drawn symbols.
  Future<void> setIconIgnorePlacement(bool value) async {
    if (value == _iconIgnorePlacement) return;

    _iconIgnorePlacement = value;
    await _rebuildLayers();
  }

  /// If true, other symbols can be visible even if they collide with the text.
  Future<void> setTextIgnorePlacement(bool value) async {
    if (value == _textIgnorePlacement) return;

    _textIgnorePlacement = value;
    await _rebuildLayers();
  }

  @override
  List<LayerProperties> get allLayerProperties => [
        SymbolLayerProperties(
          iconSize: [Expressions.get, 'iconSize'],
          iconImage: [Expressions.get, 'iconImage'],
          iconRotate: [Expressions.get, 'iconRotate'],
          iconOffset: [Expressions.get, 'iconOffset'],
          iconAnchor: [Expressions.get, 'iconAnchor'],
          iconOpacity: [Expressions.get, 'iconOpacity'],
          iconColor: [Expressions.get, 'iconColor'],
          iconHaloColor: [Expressions.get, 'iconHaloColor'],
          iconHaloWidth: [Expressions.get, 'iconHaloWidth'],
          iconHaloBlur: [Expressions.get, 'iconHaloBlur'],
          // note that web does not support setting this in a fully data driven
          // way this is a upstream issue
          textFont: kIsWeb
              ? null
              : [
                  Expressions.caseExpression,
                  [Expressions.has, 'fontNames'],
                  [Expressions.get, 'fontNames'],
                  [
                    Expressions.literal,
                    ["Open Sans Regular", "Arial Unicode MS Regular"]
                  ],
                ],
          textField: [Expressions.get, 'textField'],
          textSize: [Expressions.get, 'textSize'],
          textMaxWidth: [Expressions.get, 'textMaxWidth'],
          textLetterSpacing: [Expressions.get, 'textLetterSpacing'],
          textJustify: [Expressions.get, 'textJustify'],
          textAnchor: [Expressions.get, 'textAnchor'],
          textRotate: [Expressions.get, 'textRotate'],
          textTransform: [Expressions.get, 'textTransform'],
          textOffset: [Expressions.get, 'textOffset'],
          textOpacity: [Expressions.get, 'textOpacity'],
          textColor: [Expressions.get, 'textColor'],
          textHaloColor: [Expressions.get, 'textHaloColor'],
          textHaloWidth: [Expressions.get, 'textHaloWidth'],
          textHaloBlur: [Expressions.get, 'textHaloBlur'],
          symbolSortKey: [Expressions.get, 'zIndex'],
          iconAllowOverlap: _iconAllowOverlap,
          iconIgnorePlacement: _iconIgnorePlacement,
          textAllowOverlap: _textAllowOverlap,
          textIgnorePlacement: _textIgnorePlacement,
        )
      ];
}
