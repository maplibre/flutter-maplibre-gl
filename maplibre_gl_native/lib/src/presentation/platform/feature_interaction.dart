import 'dart:math';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import '../../engine/map_session.dart';
import '../../protocol/protocol.dart';

/// Hit-testing of the interactive style layers, and the feature events that
/// come out of it: taps, and the arbitration a feature drag needs.
///
/// The gesture handler asks the questions; this decides what counts as a hit
/// and shapes the payloads the maplibre_gl controller decodes.
class FeatureInteraction {
  FeatureInteraction({
    required MapSession? Function() session,
    required void Function(Map<String, dynamic> payload) onFeatureTapped,
    required void Function(Map<String, dynamic> payload) onMapClick,
    required void Function(Map<String, dynamic> payload) onFeatureDragged,
  }) : _session = session,
       _onFeatureTapped = onFeatureTapped,
       _onMapClick = onMapClick,
       _onFeatureDragged = onFeatureDragged;

  /// Half-size of the hit-test rect around the touch point, in logical
  /// pixels. Without it a feature must be hit on its exact rendered geometry,
  /// which makes small symbols nearly ungrabbable; the Android implementation
  /// uses the same +-10 px rect for taps and drags.
  static const _touchTolerance = 10.0;

  final MapSession? Function() _session;
  final void Function(Map<String, dynamic> payload) _onFeatureTapped;
  final void Function(Map<String, dynamic> payload) _onMapClick;
  final void Function(Map<String, dynamic> payload) _onFeatureDragged;

  /// Layer ids added with `enableInteraction`, in add order (bottom to top).
  final List<String> _layerIds = <String>[];

  /// Whether annotation drag is enabled (widget `dragEnabled`).
  bool dragEnabled = true;

  /// Whether a consumed feature tap also emits the map click.
  bool featureTapsTriggersMapClick = false;

  void registerLayer(String layerId) {
    if (!_layerIds.contains(layerId)) _layerIds.add(layerId);
  }

  void unregisterLayer(String layerId) => _layerIds.remove(layerId);

  /// Interactive layer ids ordered topmost first, for hit-testing.
  List<String> get _hitTestOrder => _layerIds.reversed.toList(growable: false);

  static Object? _featureId(Map<String, dynamic> feature) =>
      feature['id'] ?? (feature['properties'] as Map?)?['id'];

  Future<Map<String, dynamic>?> _topFeatureAt(Point<double> point) async {
    final session = requireSession(_session());
    return session.query(
      QueryTopFeatureQuery(
        session.id,
        x: point.x,
        y: point.y,
        layerIds: _hitTestOrder,
        tolerance: _touchTolerance,
      ),
    );
  }

  /// Tap entry point for the map widget: hit-tests the interactive layers and
  /// emits a feature tap (and/or the map click, matching the reference
  /// backends' featureTapsTriggersMapClick semantics).
  Future<void> handleTap(Point<double> point, LatLng latLng) async {
    final hit = _layerIds.isEmpty ? null : await _topFeatureAt(point);
    if (hit != null) {
      final feature = (hit['feature'] as Map).cast<String, dynamic>();
      _onFeatureTapped(<String, dynamic>{
        'id': _featureId(feature),
        'point': point,
        'latLng': latLng,
        'layerId': hit['layerId'],
      });
      if (!featureTapsTriggersMapClick) return;
    }
    _onMapClick(<String, dynamic>{'point': point, 'latLng': latLng});
  }

  /// Hit-tests for a draggable feature at [point]; returns the feature map or
  /// null. Called by the widget's pan gesture to arbitrate drag vs camera pan.
  Future<Map<String, dynamic>?> queryDraggableFeature(
    Point<double> point,
  ) async {
    if (!dragEnabled || _layerIds.isEmpty) return null;
    final hit = await _topFeatureAt(point);
    if (hit == null) return null;
    final feature = (hit['feature'] as Map).cast<String, dynamic>();
    final properties = feature['properties'] as Map?;
    return properties?['draggable'] == true ? feature : null;
  }

  /// Emits a feature drag event with the exact payload shape the controller
  /// decodes (eventType is a DragEventType name: start/drag/end).
  void emitDrag({
    required Map<String, dynamic> feature,
    required Point<double> point,
    required LatLng origin,
    required LatLng current,
    required LatLng delta,
    required String eventType,
  }) {
    // Symbol placement changes normally cross-fade over ~300ms, which makes a
    // dragged symbol trail its position; disable the fade while a drag is
    // active so per-move source updates apply instantly.
    // A drag can end while the map is being torn down: no session means
    // nothing to restore, and the event itself must still reach the app.
    final session = _session();
    if (session != null && (eventType == 'start' || eventType == 'end')) {
      session.send(
        SetPlacementTransitionsCommand(
          session.id,
          enabled: eventType == 'end',
        ),
      );
    }
    _onFeatureDragged(<String, dynamic>{
      'id': _featureId(feature),
      'point': point,
      'origin': origin,
      'current': current,
      'delta': delta,
      'eventType': eventType,
    });
  }
}
