// ignore_for_file: invalid_use_of_internal_member

@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/integrations/web_app_start_integration.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('WebAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when tracing is enabled', () {
      setUp(() {
        fixture.options.tracesSampleRate = 1.0;
      });

      test('adds sdk integration', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.options.sdk.integrations.length, 1);
        expect(fixture.options.sdk.integrations.first, 'WebAppStart');
      });

      test('sets transaction ID on timeToDisplayTracker', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.fakeTimeToDisplayTracker.transactionId, isNotNull);
      });

      test('adds post frame callback', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.fakeFrameHandler.postFrameCallback, isNotNull);
      });

      test(
          'creates transaction with correct context when frame callback executes',
          () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        // Wait for the async frame callback to complete
        await Future<void>.delayed(Duration(milliseconds: 10));

        // Verify that startTransactionWithContext was called
        verify(fixture.mockHub.startTransactionWithContext(any,
                startTimestamp: anyNamed('startTimestamp')))
            .called(1);
      });

      test('tracks time to display when frame callback executes', () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        // Wait for the async frame callback to complete
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(fixture.fakeTimeToDisplayTracker.trackCalled, isTrue);
        expect(
            fixture.fakeTimeToDisplayTracker.lastTrackedTransaction, isNotNull);
      });

      test('finishes transaction when frame callback executes', () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        // Wait for the async frame callback to complete
        await Future<void>.delayed(Duration(milliseconds: 10));

        verify(fixture.mockTransaction
                .finish(endTimestamp: anyNamed('endTimestamp')))
            .called(1);
      });

      test('uses correct start timestamp from clock', () {
        final fixedTime = DateTime(2023, 1, 1, 12, 0, 0);
        fixture.options.clock = () => fixedTime;
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        // Trigger the frame callback manually to cause transaction creation
        final callback = fixture.fakeFrameHandler.postFrameCallback;
        if (callback != null) {
          callback(Duration.zero);
        }

        // Verify that startTransactionWithContext was called with the fixed timestamp
        verify(fixture.mockHub
                .startTransactionWithContext(any, startTimestamp: fixedTime))
            .called(1);
      });

      test('uses clock for end timestamp in frame callback', () async {
        var clockCallCount = 0;
        final startTime = DateTime(2023, 1, 1, 12, 0, 0);
        final endTime = DateTime(2023, 1, 1, 12, 0, 1);

        fixture.options.clock = () {
          clockCallCount++;
          return clockCallCount == 1 ? startTime : endTime;
        };

        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        // Wait for the async frame callback to complete
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(fixture.fakeTimeToDisplayTracker.lastTtidEndTimestamp,
            equals(endTime));
        verify(fixture.mockTransaction.finish(endTimestamp: endTime)).called(1);
      });

      test('maintains transaction ID consistency between setup and tracking',
          () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        final transactionIdAfterSetup =
            fixture.fakeTimeToDisplayTracker.transactionId;
        expect(transactionIdAfterSetup, isNotNull);

        // Wait for the async frame callback to complete
        await Future<void>.delayed(Duration(milliseconds: 10));

        // Verify transaction was created and tracking was called
        verify(fixture.mockHub.startTransactionWithContext(any,
                startTimestamp: anyNamed('startTimestamp')))
            .called(1);
        expect(fixture.fakeTimeToDisplayTracker.trackCalled, isTrue);
      });
    });

    group('when tracing is disabled', () {
      setUp(() {
        fixture.options.tracesSampleRate = null;
      });

      test('does not add sdk integration', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.options.sdk.integrations, isEmpty);
      });

      test('does not set transaction ID on timeToDisplayTracker', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.fakeTimeToDisplayTracker.transactionId, isNull);
      });

      test('does not add post frame callback', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.fakeFrameHandler.postFrameCallback, isNull);
      });

      test('does not create any transactions', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        verifyNever(fixture.mockHub.startTransactionWithContext(any,
            startTimestamp: anyNamed('startTimestamp')));
      });
    });

    group('integration constants', () {
      test('has correct integration name', () {
        expect(WebAppStartIntegration.integrationName, equals('WebAppStart'));
      });
    });
  });
}

class _FakeTimeToDisplayTracker implements TimeToDisplayTracker {
  @override
  SpanId? transactionId;

  bool trackCalled = false;
  ISentrySpan? lastTrackedTransaction;
  DateTime? lastTtidEndTimestamp;

  @override
  Future<void> track(ISentrySpan transaction,
      {DateTime? ttidEndTimestamp}) async {
    trackCalled = true;
    lastTrackedTransaction = transaction;
    lastTtidEndTimestamp = ttidEndTimestamp;
  }

  @override
  void clear() {}

  @override
  Future<void> cancelUnfinishedSpans(
      covariant transaction, DateTime endTimestamp) async {}

  @override
  DateTime? get pendingTTFDEndTimestamp => null;

  @override
  Future<void> reportFullyDisplayed(
      {SpanId? spanId, DateTime? endTimestamp}) async {}

  @override
  SentryFlutterOptions get options => throw UnimplementedError();
}

class Fixture {
  final options = defaultTestOptions();
  final mockHub = MockHub();
  final mockTransaction = MockSentryTracer();
  final fakeTimeToDisplayTracker = _FakeTimeToDisplayTracker();
  final fakeFrameHandler = FakeFrameCallbackHandler();

  late final Hub hub;

  Fixture() {
    // Setup default mocks
    when(mockHub.options).thenReturn(options);
    when(mockHub.startTransactionWithContext(any,
            startTimestamp: anyNamed('startTimestamp')))
        .thenReturn(mockTransaction);
    when(mockTransaction.finish(endTimestamp: anyNamed('endTimestamp')))
        .thenAnswer((_) async {});

    // Setup options with fake tracker
    options.timeToDisplayTracker = fakeTimeToDisplayTracker;

    hub = mockHub;
  }

  WebAppStartIntegration getSut() {
    return WebAppStartIntegration(fakeFrameHandler);
  }
}
