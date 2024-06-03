@TestOn('vm')
library dart_test;

import 'package:sentry/src/hub.dart';
import 'package:sentry/src/protocol/sentry_level.dart';
import 'package:sentry/src/protocol/span_status.dart';
import 'package:sentry/src/sentry_isolate.dart';
import 'package:sentry/src/sentry_options.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_sentry_client.dart';

void main() {
  group("SentryIsolate", () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds error listener', () async {
      final throwingClosure = (String message) async {
        throw StateError(message);
      };

      await SentryIsolate.spawn(throwingClosure, "message", hub: fixture.hub);
      await Future.delayed(Duration(milliseconds: 10));

      expect(fixture.hub.captureEventCalls.first, isNotNull);
    });

    test('marks transaction as internal error if no status', () async {
      final exception = StateError('error');
      final stackTrace = StackTrace.current.toString();

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      hub.bindClient(client);

      hub.startTransaction('name', 'operation', bindToScope: true);

      await SentryIsolate.handleIsolateError(
          hub, [exception.toString(), stackTrace]);

      final span = hub.getSpan();

      expect(span?.status, const SpanStatus.internalError());

      await span?.finish();
    });

    test('sets level to error instead of fatal', () async {
      final exception = StateError('error');
      final stackTrace = StackTrace.current.toString();

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      hub.bindClient(client);

      fixture.options.markAutomaticallyCollectedErrorsAsFatal = false;

      await SentryIsolate.handleIsolateError(
          hub, [exception.toString(), stackTrace]);

      final capturedEvent = client.captureEventCalls.last.event;
      expect(capturedEvent.level, SentryLevel.error);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn)..tracesSampleRate = 1.0;
}
