import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group('Hub', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when using idle spans', () {
      test('clears active idle span when ended directly', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(seconds: 1),
          childSpanTimeout: Duration(seconds: 1),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;
        expect(hub.idleSpan, isNotNull);

        hub.idleSpan
          ?..status = SentrySpanStatusV2.cancelled
          ..end();
        await Future<void>.delayed(Duration.zero);

        expect(idleSpan.isEnded, isTrue);
        expect(idleSpan.status, equals(SentrySpanStatusV2.cancelled));
        expect(hub.idleSpan, isNull);
      });

      test('clears active idle span when idle span instance is ended directly',
          () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(seconds: 1),
          childSpanTimeout: Duration(seconds: 1),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;
        expect(hub.idleSpan, isNotNull);

        idleSpan.end();
        await Future<void>.delayed(Duration.zero);

        expect(idleSpan.isEnded, isTrue);
        expect(hub.idleSpan, isNull);
      });

      test('does not extend idle timeout when unrelated spans end', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(milliseconds: 120),
          childSpanTimeout: Duration(seconds: 2),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;

        await Future<void>.delayed(Duration(milliseconds: 40));
        final unrelatedSpan = hub.startInactiveSpan(
          'unrelated-root',
          parentSpan: null,
        ) as RecordingSentrySpanV2;
        unrelatedSpan.end();

        await Future<void>.delayed(Duration(milliseconds: 90));
        expect(idleSpan.isEnded, isTrue);
      });

      test('times out based on the oldest active child span', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(seconds: 1),
          childSpanTimeout: Duration(milliseconds: 200),
          finalTimeout: Duration(seconds: 2),
        ) as RecordingSentrySpanV2;

        final child1 =
            hub.startInactiveSpan('child-1') as RecordingSentrySpanV2;
        await Future<void>.delayed(Duration(milliseconds: 120));
        final child2 =
            hub.startInactiveSpan('child-2') as RecordingSentrySpanV2;

        await Future<void>.delayed(Duration(milliseconds: 120));
        expect(idleSpan.isEnded, isTrue);
        expect(child1.isEnded, isTrue);
        expect(child2.isEnded, isTrue);
      });

      test('finishes active children when final timeout is reached', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(seconds: 1),
          childSpanTimeout: Duration(seconds: 1),
          finalTimeout: Duration(milliseconds: 180),
        ) as RecordingSentrySpanV2;

        final childSpan =
            hub.startInactiveSpan('child') as RecordingSentrySpanV2;

        await Future<void>.delayed(Duration(milliseconds: 240));
        expect(idleSpan.isEnded, isTrue);
        expect(idleSpan.status, equals(SentrySpanStatusV2.deadlineExceeded));
        expect(childSpan.isEnded, isTrue);
        expect(childSpan.status, equals(SentrySpanStatusV2.cancelled));
        expect(childSpan.endTimestamp, isNotNull);
        expect(idleSpan.endTimestamp, isNotNull);
        final endTimestampDelta =
            idleSpan.endTimestamp!.difference(childSpan.endTimestamp!).abs();
        expect(endTimestampDelta, lessThan(Duration(milliseconds: 10)));
      });

      test('trims idle span end timestamp to latest finished child', () async {
        final hub = fixture.getSut();
        final idleSpan = hub.startIdleSpan(
          'idle-root',
          idleTimeout: Duration(milliseconds: 100),
          childSpanTimeout: Duration(seconds: 1),
          finalTimeout: Duration(seconds: 1),
          trimIdleSpanEndTimestamp: true,
        ) as RecordingSentrySpanV2;

        final childSpan =
            hub.startInactiveSpan('child') as RecordingSentrySpanV2;
        await Future<void>.delayed(Duration(milliseconds: 40));
        childSpan.end();

        await Future<void>.delayed(Duration(milliseconds: 140));
        expect(idleSpan.isEnded, isTrue);
        expect(idleSpan.endTimestamp, equals(childSpan.endTimestamp));
      });
    });
  });
}

class Fixture {
  final client = MockSentryClient();
  final recorder = MockClientReportRecorder();
  final options = defaultTestOptions();

  Hub getSut({
    double? tracesSampleRate = 1.0,
    SentryTraceLifecycle traceLifecycle = SentryTraceLifecycle.streaming,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.traceLifecycle = traceLifecycle;

    final hub = Hub(options);
    hub.bindClient(client);
    options.recorder = recorder;

    return hub;
  }
}
