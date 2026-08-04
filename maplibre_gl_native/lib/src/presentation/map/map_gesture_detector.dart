import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../gestures/map_gestures.dart';

/// The map's touch layer: the raw pointer stream plus the four recognizers,
/// all wired to [handler], which owns the arbitration between them.
///
/// This widget is only the wiring. Every decision (what counts as a pinch, a
/// shove, a feature drag, a fling) lives in [MapGestureHandler].
class MapGestureDetector extends StatelessWidget {
  const MapGestureDetector({
    super.key,
    required this.handler,
    required this.child,
  });

  /// Pan-start touch slop for the map's scale recognizer, in logical pixels
  /// (Android SDK parity; the recognizer's pan slop is twice this value).
  ///
  /// A stock GestureDetector starts panning after Flutter's ~18 px touch
  /// slop, while the Android SDK map moves after ~4 dp. Tightening the slop
  /// on the scale recognizer only (taps and long-presses keep stock
  /// behavior) closes the pan-start latency gap without destabilizing the
  /// gesture arena.
  static const _touchSlop = 4.0;

  final MapGestureHandler handler;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: handler.onPointerDown,
      onPointerMove: handler.onPointerMove,
      onPointerUp: handler.onPointerUp,
      onPointerCancel: handler.onPointerCancel,
      onPointerSignal: handler.onPointerSignal,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          ScaleGestureRecognizer: _factory<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..gestureSettings = const DeviceGestureSettings(
                touchSlop: _touchSlop,
              )
              ..onStart = handler.onScaleStart
              ..onUpdate = handler.onScaleUpdate
              ..onEnd = handler.onScaleEnd,
          ),
          TapGestureRecognizer: _factory<TapGestureRecognizer>(
            () => TapGestureRecognizer(debugOwner: this),
            (recognizer) => recognizer.onTapUp = handler.onTapUp,
          ),
          DoubleTapGestureRecognizer: _factory<DoubleTapGestureRecognizer>(
            () => DoubleTapGestureRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..onDoubleTapDown = handler.onDoubleTapDown
              ..onDoubleTap = handler.onDoubleTap,
          ),
          LongPressGestureRecognizer: _factory<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..onLongPressStart = handler.onLongPressStart
              ..onLongPressMoveUpdate = handler.onLongPressMoveUpdate
              ..onLongPressEnd = handler.onLongPressEnd,
          ),
        },
        child: child,
      ),
    );
  }

  static GestureRecognizerFactoryWithHandlers<R>
  _factory<R extends GestureRecognizer>(
    R Function() create,
    void Function(R recognizer) initialize,
  ) => GestureRecognizerFactoryWithHandlers<R>(create, initialize);
}
