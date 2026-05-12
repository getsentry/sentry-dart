@TestOn('vm')
library;

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_run_zoned_guarded.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group("$SentryRunZonedGuarded", () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('calls onError', () async {
      final error = StateError("StateError");
      var onErrorCalled = false;

      final completer = Completer<void>();
      SentryRunZonedGuarded.sentryRunZonedGuarded(
        fixture.hub,
        () {
          throw error;
        },
        (error, stackTrace) {
          onErrorCalled = true;
          completer.complete();
        },
      );

      await completer.future;

      expect(onErrorCalled, true);
    });

    test('calls zoneSpecification print', () async {
      var printCalled = false;
      final completer = Completer<void>();

      final zoneSpecification = ZoneSpecification(
        print: (self, parent, zone, line) {
          printCalled = true;
          completer.complete();
        },
      );
      SentryRunZonedGuarded.sentryRunZonedGuarded(
        fixture.hub,
        () {
          print('foo');
        },
        null,
        zoneSpecification: zoneSpecification,
      );

      await completer.future;

      expect(printCalled, true);
    });

    test('marks transaction as internal error if no status', () async {
      final exception = StateError('error');

      final client = MockSentryClient();
      final hub = Hub(fixture.options);
      hub.bindClient(client);
      hub.startTransaction('name', 'operation', bindToScope: true);

      final completer = Completer<void>();
      SentryRunZonedGuarded.sentryRunZonedGuarded(
        hub,
        () {
          throw exception;
        },
        (error, stackTrace) {
          completer.complete();
        },
      );

      await completer.future;

      final span = hub.getSpan();
      expect(span?.status, const SpanStatus.internalError());
      await span?.finish();
    });

    test(
        'invokes user onError synchronously and captures the event '
        '(regression for #3541)', () async {
      // Before the fix `sentryOnError` was declared `async`, returning a
      // `Future<void>` that `runZonedGuarded` discarded. The user's
      // `onError` only ran after `await _captureError(...)` resolved on
      // a later microtask, which meant a rethrow from `onError` became
      // an uncaught async error of the same zone — recursively
      // re-entering `sentryOnError` until Dart silently dropped it.
      //
      // After the fix `sentryOnError` is synchronous: `_captureError` is
      // fire-and-forget via `unawaited`, and the user's `onError` runs
      // (and may rethrow cleanly) before `sentryRunZonedGuarded`
      // returns. The clearest sync-vs-async discriminator is whether
      // the user's onError has been invoked by the time control returns
      // to the caller.
      final client = MockSentryClient();
      final hub = Hub(fixture.options);
      hub.bindClient(client);

      var userOnErrorCalled = false;
      var userOnErrorCalledSyncFromCaller = false;

      SentryRunZonedGuarded.sentryRunZonedGuarded(
        hub,
        () => throw StateError('boom'),
        (error, stackTrace) {
          userOnErrorCalled = true;
        },
      );
      // Synchronous snapshot: with the sync handler this must already
      // be `true`; with the broken async handler it would still be
      // `false` because `await _captureError(...)` had not yet
      // resolved.
      userOnErrorCalledSyncFromCaller = userOnErrorCalled;

      expect(userOnErrorCalledSyncFromCaller, isTrue,
          reason: "sentryOnError must invoke the user's onError synchronously, "
              "not after an awaited microtask. Otherwise a rethrow from "
              "onError becomes an unhandled async error of the same zone "
              "and recursively re-enters sentryOnError until Dart drops "
              "the error.");

      // The unawaited `_captureError` still reaches the client; we just
      // observe it after microtasks drain.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.captureEventCalls, hasLength(1),
          reason: 'The Sentry event must still be captured even though '
              '`_captureError` is now fire-and-forget.');
    });

    test('sets level to error instead of fatal', () async {
      final client = MockSentryClient();
      final hub = Hub(fixture.options);
      hub.bindClient(client);
      fixture.options.markAutomaticallyCollectedErrorsAsFatal = false;

      final exception = StateError('error');

      final completer = Completer<void>();
      SentryRunZonedGuarded.sentryRunZonedGuarded(
        hub,
        () {
          throw exception;
        },
        (error, stackTrace) {
          completer.complete();
        },
      );

      await completer.future;

      final capturedEvent = client.captureEventCalls.last.event;
      expect(capturedEvent.level, SentryLevel.error);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
}
