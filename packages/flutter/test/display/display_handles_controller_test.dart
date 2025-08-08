import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/display/display_timing_controller.dart';
import 'package:sentry_flutter/src/display/display_transaction_engine.dart';
import 'package:sentry_flutter/src/display/display_txn.dart';

void main() {
  group('Display handles and controller', () {
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

    test(
        'route handle ends TTID via controller, idempotent and invalidation-aware',
        () {
      final handle = controller.startRoute(name: 'r', now: now);

      final ttidEnd = now.add(const Duration(milliseconds: 10));
      handle.endTtid(ttidEnd);
      handle.endTtid(ttidEnd); // idempotent

      final snap = engine.snapshot();
      expect(snap.route, isA<Active>());
      final active = snap.route as Active;
      expect(active.ttidOpen, isFalse);
      expect(active.txn.ttidEndedAt, ttidEnd);

      // Invalidate by starting a new route; old handle is ignored
      final nextNow = now.add(const Duration(milliseconds: 20));
      controller.startRoute(name: 'other', now: nextNow);
      handle.reportFullyDisplayed(nextNow);
      final snap2 = engine.snapshot();
      expect(snap2.route, isA<Active>());
      final active2 = snap2.route as Active;
      expect(active2.txn.name, 'other');
      expect(active2.txn.ttfdEndedAt, isNull);
    });

    test('app-start handle routes to root slot', () {
      final h = controller.startApp(name: 'root /', now: now);
      h.endTtid(now);

      final snap = engine.snapshot();
      expect(snap.root, isA<Active>());
      final active = snap.root as Active;
      expect(active.ttidOpen, isFalse);
      expect(active.txn.ttidEndedAt, now);
    });

    test('abortCurrent delegates to engine and invalidates current handle',
        () async {
      final handle = controller.startRoute(name: 'r', now: now);
      // abort should invalidate token; further calls no-op
      final abortAt = now.add(const Duration(milliseconds: 5));
      controller.abortCurrent(slot: DisplaySlot.route, when: abortAt);

      final snap = engine.snapshot();
      expect(snap.route, isA<Aborted>());
      final aborted = snap.route as Aborted;
      expect(aborted.txn.ttfdEndedAt, abortAt);

      // old handle should be ignored
      handle.reportFullyDisplayed(now.add(const Duration(milliseconds: 10)));
      final snap2 = engine.snapshot();
      expect(snap2.route, isA<Aborted>());
    });

    test('autoFinishAfter is passed through to the engine', () async {
      controller.startRoute(
        name: 'r',
        now: now,
        autoFinishAfter: const Duration(milliseconds: 10),
      );
      // Let timer elapse
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final snap = engine.snapshot();
      expect(snap.route, isA<Finished>());
    });
  });
}
