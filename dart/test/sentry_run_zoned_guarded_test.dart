@TestOn('vm')
library dart_test;

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_run_zoned_guarded.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group("SentryRunZonedGuarded", () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    // increase coverage of captureError

    test('marks transaction as internal error if no status', () async {
      final exception = StateError('error');
      final stackTrace = StackTrace.current;

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      hub.bindClient(client);

      hub.startTransaction('name', 'operation', bindToScope: true);

      await SentryRunZonedGuarded.captureError(
        hub,
        fixture.options,
        exception,
        stackTrace,
      );

      final span = hub.getSpan();

      expect(span?.status, const SpanStatus.internalError());

      await span?.finish();
    });

    test('calls onError', () async {
      final error = StateError("StateError");
      var onErrorCalled = false;

      SentryRunZonedGuarded.sentryRunZonedGuarded(
        () {
          throw error;
        },
        (error, stackTrace) {
          onErrorCalled = true;
        },
      );

      await Future.delayed(Duration(milliseconds: 10));

      expect(onErrorCalled, true);
    });

    test('calls zoneSpecification print', () async {
      var printCalled = false;

      final zoneSpecification = ZoneSpecification(
        print: (self, parent, zone, line) {
          printCalled = true;
        },
      );
      SentryRunZonedGuarded.sentryRunZonedGuarded(
        () {
          print('foo');
        },
        null,
        zoneSpecification: zoneSpecification,
      );

      await Future.delayed(Duration(milliseconds: 10));

      expect(printCalled, true);
    });

    test('sets level to error instead of fatal', () async {
      final exception = StateError('error');
      final stackTrace = StackTrace.current;

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      hub.bindClient(client);

      fixture.options.markAutomaticallyCollectedErrorsAsFatal = false;
      await SentryRunZonedGuarded.captureError(
        hub,
        fixture.options,
        exception,
        stackTrace,
      );

      final capturedEvent = client.captureEventCalls.last.event;
      expect(capturedEvent.level, SentryLevel.error);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
}
