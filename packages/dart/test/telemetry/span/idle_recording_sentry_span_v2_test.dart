// ignore_for_file: invalid_use_of_internal_member

import 'package:fake_async/fake_async.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../../mocks/mock_sentry_client.dart';
import '../../test_utils.dart';

void main() {
  group('$IdleRecordingSentrySpanV2', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('preserves the latest minimum end when resuming idle completion', () {
      fakeAsync((async) {
        final sut = fixture.getSut();
        final earlierEnd = fixture.start.add(const Duration(seconds: 1));
        final latestEnd = fixture.start.add(const Duration(seconds: 2));

        sut.pauseIdleTimeout();
        sut.resumeIdleTimeout(minimumEndTimestamp: earlierEnd);
        sut.resumeIdleTimeout(minimumEndTimestamp: latestEnd);
        sut.resumeIdleTimeout(minimumEndTimestamp: earlierEnd);
        sut.end(endTimestamp: fixture.start.add(const Duration(seconds: 3)));

        expect(sut.endTimestamp, latestEnd);
      });
    });

    test('preserves the minimum end when resuming without a timestamp', () {
      fakeAsync((async) {
        final sut = fixture.getSut();
        final minimumEnd = fixture.start.add(const Duration(seconds: 1));

        sut.resumeIdleTimeout(minimumEndTimestamp: minimumEnd);
        sut.pauseIdleTimeout();
        sut.resumeIdleTimeout();
        sut.end(endTimestamp: fixture.start.add(const Duration(seconds: 2)));

        expect(sut.endTimestamp, minimumEnd);
      });
    });

    test('ignores idle timeout changes after completion', () {
      fakeAsync((async) {
        final sut = fixture.getSut();
        final end = fixture.start.add(const Duration(seconds: 1));
        sut.end(endTimestamp: end);

        sut.pauseIdleTimeout();
        sut.resumeIdleTimeout(
          minimumEndTimestamp: end.add(const Duration(seconds: 1)),
        );
        async.elapse(const Duration(minutes: 1));

        expect(sut.endTimestamp, end);
        expect(async.pendingTimers, isEmpty);
        expect(fixture.client.captureSpanCalls, hasLength(1));
      });
    });
  });
}

class Fixture {
  final start = DateTime.utc(2026, 9, 16);
  final client = MockSentryClient();
  final options = defaultTestOptions()
    ..tracesSampleRate = 1
    ..traceLifecycle = SentryTraceLifecycle.stream;

  IdleRecordingSentrySpanV2 getSut() {
    options.clock = () => start;
    final hub = Hub(options)..bindClient(client);
    return hub.startIdleSpan('test', trimIdleSpanEndTimestamp: true)
        as IdleRecordingSentrySpanV2;
  }
}
