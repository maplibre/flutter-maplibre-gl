import 'dart:math' show Point;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show LatLng;
import 'package:maplibre_gl_web/src/feature_drag.dart';

/// A press on a draggable feature reported `start` on mousedown and `end` on
/// mouseup, so a plain click was a drag. Android and iOS only start a drag
/// once the pointer has moved, with a zero delta, and report no tap after it.
void main() {
  const down = Point<double>(100, 100);
  // One CSS pixel per 0.001 degree of longitude, enough to read the deltas.
  LatLng at(Point<double> p) => LatLng(0, p.x / 1000);

  test('a click reports no drag and stays a click', () {
    final tracker = FeatureDragTracker()..down('a', down);

    const nudge = Point<double>(102, 101);
    expect(tracker.move(nudge, at(nudge)), isNull);
    expect(tracker.isDragging, isFalse);
    expect(tracker.up(nudge, at(nudge)), isNull);
    expect(tracker.takeClickAfterDrag(), isFalse);
  });

  test('a drag starts past the threshold with a zero delta', () {
    final tracker = FeatureDragTracker()..down('a', down);

    const past = Point<double>(103, 100);
    final start = tracker.move(past, at(past))!;
    expect(start['eventType'], 'start');
    expect(start['id'], 'a');
    expect(start['point'], past);
    expect(start['origin'], at(past));
    expect(start['current'], at(past));
    expect(start['delta'], const LatLng(0, 0));

    const next = Point<double>(110, 100);
    final drag = tracker.move(next, at(next))!;
    expect(drag['eventType'], 'drag');
    expect(drag['origin'], at(past));
    expect(drag['current'], at(next));
    expect((drag['delta'] as LatLng).longitude, closeTo(0.007, 1e-9));

    const last = Point<double>(112, 100);
    final end = tracker.up(last, at(last))!;
    expect(end['eventType'], 'end');
    expect(end['origin'], at(past));
    expect((end['delta'] as LatLng).longitude, closeTo(0.002, 1e-9));
    expect(tracker.isPressed, isFalse);
  });

  test('the click that ends a drag is dropped once', () {
    final tracker = FeatureDragTracker()..down('a', down);
    const away = Point<double>(120, 100);
    tracker.move(away, at(away));
    // Back near where it went down: maplibre-gl-js would still fire a click.
    tracker.up(down, at(down));

    expect(tracker.takeClickAfterDrag(), isTrue);
    expect(tracker.takeClickAfterDrag(), isFalse);
  });

  test('a new press clears a click left over from a drag', () {
    final tracker = FeatureDragTracker()..down('a', down);
    const away = Point<double>(120, 100);
    tracker.move(away, at(away));
    // Released far away: maplibre-gl-js fires no click to take the flag.
    tracker.up(away, at(away));

    tracker.pointerDown();
    expect(tracker.takeClickAfterDrag(), isFalse);
  });

  test('moves without a press on a draggable feature report nothing', () {
    final tracker = FeatureDragTracker();
    const p = Point<double>(150, 150);
    expect(tracker.move(p, at(p)), isNull);
    expect(tracker.up(p, at(p)), isNull);
  });

  test('a release outside the map ends the drag once', () {
    final tracker = FeatureDragTracker()..down('a', down);
    const away = Point<double>(120, 100);
    tracker.move(away, at(away));
    const edge = Point<double>(140, 100);
    tracker.move(edge, at(edge));

    // No mouseup reaches the map: the window's ends the press.
    final end = tracker.upOutside()!;
    expect(end['eventType'], 'end');
    expect(end['id'], 'a');
    expect(end['point'], edge);
    expect(end['origin'], at(away));
    expect(end['current'], at(edge));
    expect(end['delta'], const LatLng(0, 0));
    expect(tracker.isPressed, isFalse);
    expect(tracker.takeClickAfterDrag(), isFalse);

    // Moves back over the map with the button up drag nothing.
    expect(tracker.move(down, at(down)), isNull);
    expect(tracker.upOutside(), isNull);
    expect(tracker.up(down, at(down)), isNull);
  });

  test('a release outside the map before the threshold reports nothing', () {
    final tracker = FeatureDragTracker()..down('a', down);
    expect(tracker.upOutside(), isNull);
    expect(tracker.isPressed, isFalse);
    const past = Point<double>(120, 100);
    expect(tracker.move(past, at(past)), isNull);
  });

  test('a new press after a lost release starts clean', () {
    final tracker = FeatureDragTracker()..down('a', down);
    const away = Point<double>(120, 100);
    tracker.move(away, at(away));
    // The release was lost: the next press ends the drag it left behind.
    final end = tracker.pointerDown()!;
    expect(end['eventType'], 'end');
    expect(end['id'], 'a');
    expect(tracker.isPressed, isFalse);

    // A press on the map, not on a draggable feature: moves report nothing.
    const later = Point<double>(200, 100);
    expect(tracker.move(later, at(later)), isNull);
    expect(tracker.pointerDown(), isNull);

    // A press on another feature is a click until it passes the threshold,
    // and its drag starts with its own origin and a zero delta.
    tracker.down('b', later);
    const nudge = Point<double>(201, 100);
    expect(tracker.move(nudge, at(nudge)), isNull);
    const past = Point<double>(205, 100);
    final start = tracker.move(past, at(past))!;
    expect(start['eventType'], 'start');
    expect(start['id'], 'b');
    expect(start['origin'], at(past));
    expect(start['delta'], const LatLng(0, 0));
  });
}
