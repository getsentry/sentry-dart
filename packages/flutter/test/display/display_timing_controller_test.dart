import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/display/display_timing_controller.dart';
import 'package:sentry_flutter/src/display/display_transaction_engine.dart';
import 'package:sentry_flutter/src/display/display_txn.dart';

void main() {
  group('DisplayTimingController', () {
    late DateTime now;
    late DisplayTransactionEngine engine;
    late DisplayTimingController controller;

    setUp(() {
      now = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      engine = DisplayTransactionEngine(
        hub: Object(),
        options: Object(),
        clock: () => now,
      );
      controller = DisplayTimingController(engine: engine);
    });

    test('currentDisplay returns handle for active slot', () {
      controller.startRoute(name: 'r', now: now);
      final handle = controller.currentDisplay(DisplaySlot.route);
      expect(handle, isNotNull);
      handle!.endTtid(now);

      final snap = engine.snapshot();
      expect(snap.route, isA<Active>());
      final active = snap.route as Active;
      expect(active.ttidOpen, isFalse);
    });

    test('currentDisplay returns null if no active token', () {
      expect(controller.currentDisplay(DisplaySlot.route), isNull);
    });
  });
}
