import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('ArgumentCallbacks', () {
    test('starts empty', () {
      final callbacks = ArgumentCallbacks<int>();
      expect(callbacks.isEmpty, isTrue);
      expect(callbacks.isNotEmpty, isFalse);
    });

    test('add makes it non-empty', () {
      final callbacks = ArgumentCallbacks<int>();
      callbacks.add((_) {});
      expect(callbacks.isEmpty, isFalse);
      expect(callbacks.isNotEmpty, isTrue);
    });

    test('call invokes a single callback', () {
      final callbacks = ArgumentCallbacks<int>();
      int? received;
      callbacks.add((value) => received = value);

      callbacks.call(42);
      expect(received, 42);
    });

    test('call invokes multiple callbacks', () {
      final callbacks = ArgumentCallbacks<int>();
      final results = <int>[];

      callbacks.add((value) => results.add(value * 1));
      callbacks.add((value) => results.add(value * 2));
      callbacks.add((value) => results.add(value * 3));

      callbacks.call(10);
      expect(results, [10, 20, 30]);
    });

    test('remove stops callback from being invoked', () {
      final callbacks = ArgumentCallbacks<int>();
      var callCount = 0;
      void callback(int _) => callCount++;

      callbacks.add(callback);
      callbacks.call(1);
      expect(callCount, 1);

      callbacks.remove(callback);
      callbacks.call(2);
      expect(callCount, 1); // not called again
    });

    test('remove non-existent callback does nothing', () {
      final callbacks = ArgumentCallbacks<int>();
      callbacks.add((_) {});
      callbacks.remove((_) {}); // different closure
      expect(callbacks.isNotEmpty, isTrue);
    });

    test('clear removes all callbacks', () {
      final callbacks = ArgumentCallbacks<int>();
      callbacks.add((_) {});
      callbacks.add((_) {});
      callbacks.clear();
      expect(callbacks.isEmpty, isTrue);
    });

    test('call with zero callbacks does not throw', () {
      final callbacks = ArgumentCallbacks<int>();
      expect(() => callbacks.call(42), returnsNormally);
    });

    test('call snapshots list to handle modification during iteration', () {
      final callbacks = ArgumentCallbacks<int>();
      final results = <int>[];

      callbacks.add((value) {
        results.add(1);
        // Modifying during iteration should not affect current call
        callbacks.add((v) => results.add(99));
      });
      callbacks.add((value) => results.add(2));

      callbacks.call(0);
      // Only the original 2 callbacks should run
      expect(results, [1, 2]);
    });
  });
}
