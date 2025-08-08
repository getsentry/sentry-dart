// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/display/display_transaction_engine.dart';
import 'package:sentry_flutter/src/display/display_txn.dart';

void main() {
  group('DisplayTransactionEngine FSM', () {
    late DateTime clockNow;
    late DisplayTransactionEngine engine;

    setUp(() {
      clockNow = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      engine = DisplayTransactionEngine(
        hub: Object(),
        options: Object(),
        clock: () => clockNow,
        defaultAutoFinishAfter: const Duration(milliseconds: 50),
      );
    });

    test('start transitions Idle → Active(ttidOpen: true)', () {
      final txn = engine.start(
        slot: DisplaySlot.route,
        name: 'route /a',
        now: clockNow,
      );

      final snap = engine.snapshot();
      expect(snap.route, isA<Active>());
      expect((snap.route as Active).ttidOpen, isTrue);
      expect((snap.route as Active).txn, same(txn));
      expect(txn.startedAt, clockNow);
      expect(txn.timeoutTimer, isNotNull);
      expect(txn.timeoutTimer!.isActive, isTrue);
    });

    test('finishTtid closes TTID but keeps Active', () {
      engine.start(slot: DisplaySlot.route, name: 'r', now: clockNow);

      final ttidEnd = clockNow.add(const Duration(milliseconds: 10));
      engine.finishTtid(slot: DisplaySlot.route, when: ttidEnd);

      final snap = engine.snapshot();
      expect(snap.route, isA<Active>());
      final active = snap.route as Active;
      expect(active.ttidOpen, isFalse);
      expect(active.txn.ttidEndedAt, ttidEnd);
    });

    test('finishTtfd after TTID transitions to Finished', () {
      engine.start(slot: DisplaySlot.route, name: 'r', now: clockNow);
      final ttidEnd = clockNow.add(const Duration(milliseconds: 10));
      engine.finishTtid(slot: DisplaySlot.route, when: ttidEnd);

      final ttfdEnd = clockNow.add(const Duration(milliseconds: 20));
      engine.finishTtfd(slot: DisplaySlot.route, when: ttfdEnd);

      final snap = engine.snapshot();
      expect(snap.route, isA<Finished>());
      final finished = snap.route as Finished;
      expect(finished.txn.ttfdEndedAt, ttfdEnd);
      expect(finished.txn.timeoutTimer, isNull);
    });

    test('finishTtfd before TTID stores pending and completes on TTID', () {
      engine.start(slot: DisplaySlot.route, name: 'r', now: clockNow);

      final pendingTtfd = clockNow.add(const Duration(milliseconds: 10));
      engine.finishTtfd(slot: DisplaySlot.route, when: pendingTtfd);

      // Still active and TTID open
      var snap = engine.snapshot();
      expect(snap.route, isA<Active>());
      final active = snap.route as Active;
      expect(active.ttidOpen, isTrue);
      expect(active.txn.pendingTtfdBeforeTtid, pendingTtfd);

      // Close TTID with a later timestamp; TTFD clamps to the later TTID end
      final ttidEnd = clockNow.add(const Duration(milliseconds: 15));
      engine.finishTtid(slot: DisplaySlot.route, when: ttidEnd);

      snap = engine.snapshot();
      expect(snap.route, isA<Finished>());
      final finished = snap.route as Finished;
      expect(finished.txn.ttidEndedAt, ttidEnd);
      expect(finished.txn.ttfdEndedAt, ttidEnd);
    });

    test('pending TTFD after TTID uses pending (no clamp needed)', () {
      engine.start(slot: DisplaySlot.route, name: 'r', now: clockNow);
      final ttidEnd = clockNow.add(const Duration(milliseconds: 10));
      engine.finishTtid(slot: DisplaySlot.route, when: ttidEnd);

      final pendingTtfd = clockNow.add(const Duration(milliseconds: 20));
      engine.finishTtfd(slot: DisplaySlot.route, when: pendingTtfd);

      final snap = engine.snapshot();
      expect(snap.route, isA<Finished>());
      final finished = snap.route as Finished;
      expect(finished.txn.ttidEndedAt, ttidEnd);
      expect(finished.txn.ttfdEndedAt, pendingTtfd);
    });

    test('abort transitions to Aborted; sets end times consistently', () {
      engine.start(slot: DisplaySlot.route, name: 'r', now: clockNow);
      final abortAt = clockNow.add(const Duration(milliseconds: 7));
      engine.abort(slot: DisplaySlot.route, when: abortAt);

      final snap = engine.snapshot();
      expect(snap.route, isA<Aborted>());
      final aborted = snap.route as Aborted;
      expect(aborted.txn.ttidEndedAt, abortAt);
      expect(aborted.txn.ttfdEndedAt, abortAt);
      expect(aborted.txn.timeoutTimer, isNull);
    });

    test('abort after TTID keeps ttfd >= ttid', () {
      engine.start(slot: DisplaySlot.route, name: 'r', now: clockNow);
      final ttidEnd = clockNow.add(const Duration(milliseconds: 10));
      engine.finishTtid(slot: DisplaySlot.route, when: ttidEnd);

      final abortAt = clockNow.add(const Duration(milliseconds: 5));
      // abort time earlier than ttid end; ttfd should be clamped to ttid end
      engine.abort(slot: DisplaySlot.route, when: abortAt);

      final snap = engine.snapshot();
      expect(snap.route, isA<Aborted>());
      final aborted = snap.route as Aborted;
      expect(aborted.txn.ttidEndedAt, ttidEnd);
      expect(aborted.txn.ttfdEndedAt, ttidEnd);
    });

    test('idempotency: finishTtid/finishTtfd multiple times', () {
      engine.start(slot: DisplaySlot.route, name: 'r', now: clockNow);
      final ttidEnd = clockNow.add(const Duration(milliseconds: 10));
      engine.finishTtid(slot: DisplaySlot.route, when: ttidEnd);
      engine.finishTtid(slot: DisplaySlot.route, when: ttidEnd);

      var snap = engine.snapshot();
      final active = snap.route as Active;
      expect(active.ttidOpen, isFalse);
      expect(active.txn.ttidEndedAt, ttidEnd);

      final ttfdEnd = clockNow.add(const Duration(milliseconds: 20));
      engine.finishTtfd(slot: DisplaySlot.route, when: ttfdEnd);
      engine.finishTtfd(slot: DisplaySlot.route, when: ttfdEnd);

      snap = engine.snapshot();
      final finished = snap.route as Finished;
      expect(finished.txn.ttfdEndedAt, ttfdEnd);
    });

    test('start auto-aborts previous Active', () {
      final first = engine.start(
        slot: DisplaySlot.route,
        name: 'first',
        now: clockNow,
      );
      expect(first.timeoutTimer, isNotNull);
      expect(first.timeoutTimer!.isActive, isTrue);

      final abortAt = clockNow.add(const Duration(milliseconds: 5));
      // New start must auto-abort the previous
      engine.start(
        slot: DisplaySlot.route,
        name: 'second',
        now: abortAt,
      );

      // Previous timer canceled
      expect(first.timeoutTimer, isNull);

      final snap = engine.snapshot();
      expect(snap.route, isA<Active>());
      expect((snap.route as Active).txn.name, 'second');
    });

    test('timeout auto-finishes TTFD', () async {
      final txn = engine.start(
        slot: DisplaySlot.route,
        name: 'r',
        now: clockNow,
        autoFinishAfter: const Duration(milliseconds: 10),
      );

      // Advance clock to a known time before the timer fires
      clockNow = clockNow.add(const Duration(milliseconds: 10));

      // Wait longer than autoFinishAfter to let the timer run
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final snap = engine.snapshot();
      expect(snap.route, isA<Finished>());
      final finished = snap.route as Finished;
      expect(finished.txn, same(txn));
      // ttfdEndedAt equals the value returned by clock() at timeout time
      expect(finished.txn.ttfdEndedAt, clockNow);
      expect(finished.txn.timeoutTimer, isNull);
    });
  });
}
