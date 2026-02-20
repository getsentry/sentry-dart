// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';
import '../mocks.mocks.dart';

void main() {
  test('fullDisplayed called with correct spanId (non-streaming)', () async {
    final mockTimeToDisplayTracker = MockTimeToDisplayTracker();
    when(mockTimeToDisplayTracker.reportFullyDisplayed(
            spanId: anyNamed('spanId')))
        .thenAnswer((_) => Future<void>.value());

    final options = SentryFlutterOptions();
    options.timeToDisplayTracker = mockTimeToDisplayTracker;

    final mockHub = MockHub();
    when(mockHub.options).thenReturn(options);

    final spanId = SpanId.newId();
    final display = SentryDisplay(spanId, hub: mockHub);

    await display.reportFullyDisplayed();

    verify(mockTimeToDisplayTracker.reportFullyDisplayed(spanId: spanId));
  });

  test('streaming path does not throw', () async {
    final options = SentryFlutterOptions()
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..timeToDisplayTrackerV2 = _ThrowingTimeToDisplayTrackerV2();

    final mockHub = MockHub();
    when(mockHub.options).thenReturn(options);

    final display = SentryDisplay(SpanId.newId(), hub: mockHub);

    await display.reportFullyDisplayed();
  });
}

class _ThrowingTimeToDisplayTrackerV2 extends TimeToDisplayTrackerV2 {
  @override
  void reportFullyDisplayed(SpanId spanId) {
    throw StateError('Failed to report');
  }
}
