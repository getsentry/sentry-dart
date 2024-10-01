@TestOn('vm')
library dart_test;

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group(RunZonedGuardedIntegration, () {
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

      final sut = fixture.getSut(runner: () async {});

      hub.startTransaction('name', 'operation', bindToScope: true);

      await sut.captureError(hub, fixture.options, exception, stackTrace);

      final span = hub.getSpan();

      expect(span?.status, const SpanStatus.internalError());

      await span?.finish();
    });

    test('calls onError', () async {
      final error = StateError("StateError");
      var onErrorCalled = false;
      RunZonedGuardedRunner runner = () async {
        throw error;
      };
      RunZonedGuardedOnError onError = (error, stackTrace) async {
        onErrorCalled = true;
      };
      final sut = fixture.getSut(runner: runner, onError: onError);

      await sut.call(fixture.hub, fixture.options);
      await Future.delayed(Duration(milliseconds: 10));

      expect(onErrorCalled, true);
    });

    test('sets level to error instead of fatal', () async {
      final exception = StateError('error');
      final stackTrace = StackTrace.current;

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      hub.bindClient(client);

      final sut = fixture.getSut(runner: () async {});

      fixture.options.markAutomaticallyCollectedErrorsAsFatal = false;
      await sut.captureError(hub, fixture.options, exception, stackTrace);

      final capturedEvent = client.captureEventCalls.last.event;
      expect(capturedEvent.level, SentryLevel.error);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions()..tracesSampleRate = 1.0;

  RunZonedGuardedIntegration getSut(
      {required RunZonedGuardedRunner runner,
      RunZonedGuardedOnError? onError}) {
    return RunZonedGuardedIntegration(runner, onError);
  }
}
