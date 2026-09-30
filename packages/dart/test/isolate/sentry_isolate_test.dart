@TestOn('vm')
library;

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/isolate/sentry_isolate.dart';
import 'package:test/test.dart';

import '../mocks/mock_sentry_client.dart';
import '../test_utils.dart';

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

    test(
      'marks streaming span as error when callback returns normally',
      () async {
        final client = MockSentryClient();
        final hub = Hub(fixture.options)..bindClient(client);

        await hub.startSpan('parent', (span) async {
          await SentryIsolate.handleIsolateError(hub, [
            StateError('error').toString(),
            StackTrace.current.toString(),
          ]);

          expect(span.status, SentrySpanStatusV2.error);
        });

        expect(
          client.captureSpanCalls.single.span.status,
          SentrySpanStatusV2.error,
        );
      },
    );

    test('marks transaction as internal error if no status', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.static;
      final exception = StateError('error');
      final stackTrace = StackTrace.current.toString();

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      hub.bindClient(client);

      hub.startTransaction('name', 'operation', bindToScope: true);

      await SentryIsolate.handleIsolateError(hub, [
        exception.toString(),
        stackTrace,
      ]);

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

      await SentryIsolate.handleIsolateError(hub, [
        exception.toString(),
        stackTrace,
      ]);

      final capturedEvent = client.captureEventCalls.last.event;
      expect(capturedEvent.level, SentryLevel.error);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
}
