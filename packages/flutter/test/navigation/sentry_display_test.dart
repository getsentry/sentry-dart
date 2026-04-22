// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group(SentryDisplay, () {
    group('when reporting fully displayed', () {
      test('calls TimeToDisplayTracker with the span id in non-streaming mode',
          () async {
        final nonStreamingTracker = MockTimeToDisplayTracker();
        when(nonStreamingTracker.reportFullyDisplayed(
                spanId: anyNamed('spanId')))
            .thenAnswer((_) => Future<void>.value());
        fixture.options.timeToDisplayTracker = nonStreamingTracker;

        final spanId = SpanId.newId();
        final sentryDisplay = fixture.getSut(spanId);

        await sentryDisplay.reportFullyDisplayed();

        verify(nonStreamingTracker.reportFullyDisplayed(spanId: spanId));
      });

      test('calls TimeToDisplayTrackerV2 with the span id in streaming mode',
          () async {
        final streamingTracker = _CapturingTimeToDisplayTrackerV2();
        fixture.options
          ..traceLifecycle = SentryTraceLifecycle.stream
          ..timeToDisplayTrackerV2 = streamingTracker;

        final spanId = SpanId.newId();
        final sentryDisplay = fixture.getSut(spanId);

        await sentryDisplay.reportFullyDisplayed();

        expect(streamingTracker.callCount, 1);
        expect(streamingTracker.reportedSpanId, spanId);
      });

      test(
          'does not throw in streaming mode when tracker throws and automated test mode is false',
          () async {
        fixture.options
          ..traceLifecycle = SentryTraceLifecycle.stream
          ..timeToDisplayTrackerV2 = _ThrowingTimeToDisplayTrackerV2()
          ..automatedTestMode = false;

        final sentryDisplay = fixture.getSut(SpanId.newId());

        await sentryDisplay.reportFullyDisplayed();
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SentryDisplay getSut(SpanId spanId) {
    return SentryDisplay(spanId, hub: Hub(options));
  }
}

class _CapturingTimeToDisplayTrackerV2 extends TimeToDisplayTrackerV2 {
  SpanId? reportedSpanId;
  int callCount = 0;

  @override
  void reportFullyDisplayed(SpanId spanId) {
    reportedSpanId = spanId;
    callCount += 1;
  }
}

class _ThrowingTimeToDisplayTrackerV2 extends TimeToDisplayTrackerV2 {
  @override
  void reportFullyDisplayed(SpanId spanId) {
    throw StateError('Failed to report');
  }
}
