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
