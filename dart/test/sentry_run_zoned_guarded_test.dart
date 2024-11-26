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

    test('calls onError', () async {
      final error = StateError("StateError");
      var onErrorCalled = false;

      SentryRunZonedGuarded.sentryRunZonedGuarded(
        fixture.hub,
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
        fixture.hub,
        () {
          print('foo');
        },
        null,
        zoneSpecification: zoneSpecification,
      );

      await Future.delayed(Duration(milliseconds: 10));

      expect(printCalled, true);
    });

    test('marks transaction as internal error if no status', () async {
      final exception = StateError('error');

      final client = MockSentryClient();
      final hub = Hub(fixture.options);
      hub.bindClient(client);
      hub.startTransaction('name', 'operation', bindToScope: true);

      SentryRunZonedGuarded.sentryRunZonedGuarded(
        hub,
        () {
          throw exception;
        },
        (error, stackTrace) {
          // Stub
        },
      );

      await Future.delayed(Duration(milliseconds: 10));

      final span = hub.getSpan();
      expect(span?.status, const SpanStatus.internalError());
      await span?.finish();
    });

    test('sets level to error instead of fatal', () async {
      final client = MockSentryClient();
      fixture.hub.bindClient(client);
      fixture.options.markAutomaticallyCollectedErrorsAsFatal = false;

      final exception = StateError('error');

      SentryRunZonedGuarded.sentryRunZonedGuarded(
        fixture.hub,
        () {
          throw exception;
        },
        (error, stackTrace) {
          // Stub
        },
      );

      await Future.delayed(Duration(milliseconds: 10));

      final capturedEvent = client.captureEventCalls.last.event;
      expect(capturedEvent.level, SentryLevel.error);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
}
