@TestOn('vm')
library;

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_handler.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: inference_failure_on_instance_creation

void main() {
  void setupMocks(Fixture fixture) {
    when(fixture.hub.startTransactionWithContext(
      any,
      startTimestamp: anyNamed('startTimestamp'),
      bindToScope: anyNamed('bindToScope'),
      waitForChildren: anyNamed('waitForChildren'),
      autoFinishAfter: anyNamed('autoFinishAfter'),
      trimEnd: anyNamed('trimEnd'),
    )).thenAnswer((invocation) {
      // Create a new tracer for each call to capture the enriched state
      final context =
          invocation.positionalArguments[0] as SentryTransactionContext;
      final startTimestamp =
          invocation.namedArguments[#startTimestamp] as DateTime?;

      final tracer = SentryTracer(
        context,
        fixture.hub,
        startTimestamp:
            startTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

      // Store the tracer so we can access it after it's enriched
      fixture._enrichedTransaction = tracer;

      // Simulate binding to scope when bindToScope is true
      final bindToScope = invocation.namedArguments[#bindToScope] as bool?;
      if (bindToScope == true) {
        fixture.scope.span = tracer;
      }
      return tracer;
    });

    when(fixture.hub.configureScope(captureAny)).thenAnswer((invocation) {
      final callback = invocation.positionalArguments[0] as ScopeCallback;
      callback(fixture.scope);
      return null;
    });

    when(fixture.hub.captureTransaction(
      any,
      traceContext: anyNamed('traceContext'),
    )).thenAnswer((_) async => SentryId.empty());

    when(fixture.nativeBinding.fetchNativeAppStart()).thenAnswer(
      (_) async => fixture.nativeAppStart,
    );
  }

  group('$NativeAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
      setupMocks(fixture);
    });

    test('added transaction has app start measurement', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      final transaction = fixture.capturedTransaction();

      final measurement = transaction.measurements['app_start_cold']!;
      expect(measurement.value, 10);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);

      final spans = transaction.spans;

      final appStartSpan = spans.firstWhereOrNull(
          (element) => element.context.description == 'Cold Start');

      final pluginRegistrationSpan = spans.firstWhereOrNull((element) =>
          element.context.description == 'App start to plugin registration');

      final sentrySetupSpan = spans.firstWhereOrNull((element) =>
          element.context.description == 'Before Sentry Init Setup');

      final firstFrameRenderSpan = spans.firstWhereOrNull(
          (element) => element.context.description == 'First frame render');

      expect(appStartSpan, isNotNull);
      expect(pluginRegistrationSpan, isNotNull);
      expect(sentrySetupSpan, isNotNull);
      expect(firstFrameRenderSpan, isNotNull);
    });

    test('added transaction has ttid measurement', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      final transaction = fixture.capturedTransaction();

      final measurement = transaction.measurements['time_to_initial_display']!;
      expect(measurement.value, 10);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);
    });

    test('added transaction has no ttfd measurement', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      final transaction = fixture.capturedTransaction();

      final measurement = transaction.measurements['time_to_full_display'];
      expect(measurement, isNull);
    });

    test('added transaction has ttfd measurement if opt in', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      // Start the app start handling
      final future = fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      // Wait a bit for the transaction to be created and tracking to start
      await Future.delayed(Duration(milliseconds: 50));

      // Report fully displayed
      await fixture.options.timeToDisplayTracker.reportFullyDisplayed();

      // Wait for the app start handling to complete
      await future;

      final transaction = fixture.capturedTransaction();

      final measurement = transaction.measurements['time_to_full_display'];
      expect(measurement, isNotNull);
    });

    test('added transaction has ttfd measurement if set before by root id',
        () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      // Start the app start handling
      final future = fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      // Wait a bit for the transaction to be created and tracking to start
      await Future.delayed(Duration(milliseconds: 50));

      // Get the actual transaction span ID that was created
      final actualTransaction = fixture._enrichedTransaction!;
      fixture.options.timeToDisplayTracker.transactionId =
          actualTransaction.context.spanId;

      await fixture.options.timeToDisplayTracker.reportFullyDisplayed(
        spanId: actualTransaction.context.spanId,
      );

      // Wait for the app start handling to complete
      await future;

      final transaction = fixture.capturedTransaction();

      final measurement = transaction.measurements['time_to_full_display'];
      expect(measurement, isNotNull);
    });

    test('ttfd end from ttid if reported end is before', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;

      // Start the app start handling
      final future = fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      // Wait a bit for the transaction to be created and tracking to start
      await Future.delayed(Duration(milliseconds: 50));

      // Get the actual transaction span ID that was created
      final actualTransaction = fixture._enrichedTransaction!;
      fixture.options.timeToDisplayTracker.transactionId =
          actualTransaction.context.spanId;

      await fixture.options.timeToDisplayTracker.reportFullyDisplayed(
        spanId: actualTransaction.context.spanId,
        endTimestamp: DateTime.fromMillisecondsSinceEpoch(5),
      );

      // Wait for the app start handling to complete
      await future;

      final transaction = fixture.capturedTransaction();

      final ttidSpan = transaction.spans.firstWhereOrNull((child) =>
          child.context.operation ==
          SentrySpanOperations.uiTimeToInitialDisplay);

      final ttfdSpan = transaction.spans.firstWhereOrNull((child) =>
          child.context.operation == SentrySpanOperations.uiTimeToFullDisplay);

      expect(ttidSpan, isNotNull);
      expect(ttfdSpan, isNotNull);
      // TTFD currently uses the reported end timestamp, not clamped to TTID
      expect(ttfdSpan?.endTimestamp, ttidSpan?.endTimestamp);
      // skip this test for now as it's extremely flaky
    }, skip: true);

    // Regression test: App start spans must be attached to the transaction
    // BEFORE track() is called. This verifies the fix for a race condition
    // where calling reportFullyDisplayed() after autoFinishAfter could cause
    // app start spans to be missing from the captured transaction.
    test('app start spans are attached before TTFD tracking starts', () async {
      // Create fresh fixture and mocks for test isolation
      final testFixture = Fixture();
      setupMocks(testFixture);

      testFixture.options.enableTimeToFullDisplayTracing = true;

      // Set sentrySetupStartTime to a value consistent with the mock timestamps
      // (pluginRegistrationTime is 10ms, so this should be after that)
      SentryFlutter.sentrySetupStartTime =
          DateTime.fromMillisecondsSinceEpoch(15);

      // Capture transaction state at the moment track() is called
      List<SentrySpan>? spansWhenTrackCalled;
      final originalTracker = testFixture.options.timeToDisplayTracker;
      testFixture.options.timeToDisplayTracker = _FakeTimeToDisplayTracker(
        originalTracker,
        onTrack: (transaction) {
          if (transaction is SentryTracer) {
            spansWhenTrackCalled = List.from(transaction.children);
          }
        },
      );

      final future = testFixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(50),
      );

      await Future.delayed(Duration(milliseconds: 50));
      await testFixture.options.timeToDisplayTracker.reportFullyDisplayed();
      await future;

      expect(spansWhenTrackCalled, isNotNull,
          reason: 'track() should have been called');
      expect(
        spansWhenTrackCalled!.any((s) => s.context.description == 'Cold Start'),
        isTrue,
        reason: 'Cold Start span must be attached before track() is called',
      );
    });

    test('no transaction if app start takes more than 60s', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(60001),
      );

      // Verify no transaction was created or bound to scope
      expect(fixture._enrichedTransaction, isNull);
      expect(fixture.scope.span, isNull);
    });

    test('added transaction is bound to scope', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );
      expect(fixture.scope.span, isNotNull);
      expect(fixture.scope.span, isA<SentryTracer>());
    });

    test('added transaction has app_start_type data', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );
      expect(fixture._enrichedTransaction?.data["app_start_type"], 'cold');
    });

    test('added transaction is not bound to scope if already set', () async {
      final alreadySet = MockSentryTracer();
      fixture.scope.span = alreadySet;

      // Mock startTransactionWithContext to not override existing span
      when(fixture.hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        bindToScope: anyNamed('bindToScope'),
        waitForChildren: anyNamed('waitForChildren'),
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: anyNamed('trimEnd'),
      )).thenAnswer((invocation) {
        // Create a new tracer for each call
        final context =
            invocation.positionalArguments[0] as SentryTransactionContext;
        final startTimestamp =
            invocation.namedArguments[#startTimestamp] as DateTime?;

        final tracer = SentryTracer(
          context,
          fixture.hub,
          startTimestamp:
              startTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
        );

        fixture._enrichedTransaction = tracer;

        // Don't bind to scope if span is already set
        final bindToScope = invocation.namedArguments[#bindToScope] as bool?;
        if (bindToScope == true && fixture.scope.span == null) {
          fixture.scope.span = tracer;
        }
        return tracer;
      });

      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );
      expect(fixture.scope.span, alreadySet);
    });
  });

  group('App start spans', () {
    late SentrySpan? coldStartSpan,
        pluginRegistrationSpan,
        sentrySetupSpan,
        firstFrameRenderSpan;
    late SentryTracer tracer;
    late Fixture fixture;
    late SentryTransaction enriched;

    final validNativeSpanTimes = {
      'correct span description': {
        'startTimestampMsSinceEpoch': 1,
        'stopTimestampMsSinceEpoch': 2,
      },
      'correct span description 2': {
        'startTimestampMsSinceEpoch': 4,
        'stopTimestampMsSinceEpoch': 6,
      },
      'correct span description 3': {
        'startTimestampMsSinceEpoch': 3,
        'stopTimestampMsSinceEpoch': 4,
      },
    };

    final invalidNativeSpanTimes = {
      'failing span with null timestamp': {
        'startTimestampMsSinceEpoch': null,
        'stopTimestampMsSinceEpoch': 3,
      },
      'failing span with string timestamp': {
        'startTimestampMsSinceEpoch': '1',
        'stopTimestampMsSinceEpoch': 3,
      },
    };

    final appStartInfoSrc = NativeAppStart(
        appStartTime: 0,
        pluginRegistrationTime: 10,
        isColdStart: true,
        nativeSpanTimes: {
          ...validNativeSpanTimes,
          ...invalidNativeSpanTimes,
        });

    setUp(() async {
      fixture = Fixture();
      tracer = fixture.tracer;

      // dartLoadingEnd needs to be set after engine end (see MockNativeChannel)
      SentryFlutter.sentrySetupStartTime =
          DateTime.fromMillisecondsSinceEpoch(15);

      setupMocks(fixture);

      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenAnswer((_) async => appStartInfoSrc);

      await fixture.call(appStartEnd: DateTime.fromMillisecondsSinceEpoch(50));
      enriched = fixture.capturedTransaction();

      final spans = enriched.spans;

      coldStartSpan = spans.firstWhereOrNull(
          (element) => element.context.description == 'Cold Start');

      pluginRegistrationSpan = spans.firstWhereOrNull((element) =>
          element.context.description == 'App start to plugin registration');

      sentrySetupSpan = spans.firstWhereOrNull((element) =>
          element.context.description == 'Before Sentry Init Setup');

      firstFrameRenderSpan = spans.firstWhereOrNull(
          (element) => element.context.description == 'First frame render');
    });

    test('includes only valid native spans', () async {
      final spans =
          enriched.spans.where((element) => element.data['native'] == true);

      expect(spans.length, validNativeSpanTimes.length);

      for (final span in spans) {
        final validSpan = validNativeSpanTimes[span.context.description];
        expect(validSpan, isNotNull);
        expect(
            span.startTimestamp,
            DateTime.fromMillisecondsSinceEpoch(
                    validSpan!['startTimestampMsSinceEpoch']!)
                .toUtc());
        expect(
            span.endTimestamp,
            DateTime.fromMillisecondsSinceEpoch(
                    validSpan['stopTimestampMsSinceEpoch']!)
                .toUtc());
      }
    });

    test('are correctly ordered', () async {
      final spans =
          enriched.spans.where((element) => element.data['native'] == true);

      final orderedSpans = spans.toList()
        ..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));

      expect(spans, orderedEquals(orderedSpans));
    });

    test('ignores invalid spans', () async {
      final spans =
          enriched.spans.where((element) => element.data['native'] == true);

      expect(spans, isNot(contains('failing span')));
    });

    test('are added by event processor', () async {
      expect(coldStartSpan, isNotNull);
      expect(pluginRegistrationSpan, isNotNull);
      expect(sentrySetupSpan, isNotNull);
      expect(firstFrameRenderSpan, isNotNull);
    });

    test('have app_start_type data set', () async {
      // Verify that app start spans have the app_start_type data set
      expect(coldStartSpan?.data["app_start_type"], "cold");
      expect(pluginRegistrationSpan?.data["app_start_type"], "cold");
      expect(sentrySetupSpan?.data["app_start_type"], "cold");
      expect(firstFrameRenderSpan?.data["app_start_type"], "cold");
    });

    test('have correct op', () async {
      const op = 'app.start.cold';
      expect(coldStartSpan?.context.operation, op);
      expect(pluginRegistrationSpan?.context.operation, op);
      expect(sentrySetupSpan?.context.operation, op);
      expect(firstFrameRenderSpan?.context.operation, op);
    });

    test('have correct parents', () async {
      expect(coldStartSpan?.context.parentSpanId, tracer.context.spanId);
      expect(pluginRegistrationSpan?.context.parentSpanId,
          coldStartSpan?.context.spanId);
      expect(
          sentrySetupSpan?.context.parentSpanId, coldStartSpan?.context.spanId);
      expect(firstFrameRenderSpan?.context.parentSpanId,
          coldStartSpan?.context.spanId);
    });

    test('have correct traceId', () async {
      final traceId = tracer.context.traceId;
      expect(coldStartSpan?.context.traceId, traceId);
      expect(pluginRegistrationSpan?.context.traceId, traceId);
      expect(sentrySetupSpan?.context.traceId, traceId);
      expect(firstFrameRenderSpan?.context.traceId, traceId);
    });

    test('have correct startTimestamp', () async {
      final appStartTime = DateTime.fromMillisecondsSinceEpoch(
              appStartInfoSrc.appStartTime.toInt())
          .toUtc();
      expect(coldStartSpan?.startTimestamp, appStartTime);
      expect(pluginRegistrationSpan?.startTimestamp, appStartTime);
      expect(sentrySetupSpan?.startTimestamp,
          pluginRegistrationSpan?.endTimestamp);
      expect(
          firstFrameRenderSpan?.startTimestamp, sentrySetupSpan?.endTimestamp);
    });

    test('have correct endTimestamp', () async {
      final appStartEnd = DateTime.fromMillisecondsSinceEpoch(50);

      final engineReadyEndtime = DateTime.fromMillisecondsSinceEpoch(
              appStartInfoSrc.pluginRegistrationTime.toInt())
          .toUtc();
      expect(coldStartSpan?.endTimestamp, appStartEnd.toUtc());
      expect(pluginRegistrationSpan?.endTimestamp, engineReadyEndtime);
      expect(sentrySetupSpan?.endTimestamp,
          SentryFlutter.sentrySetupStartTime?.toUtc());
      expect(firstFrameRenderSpan?.endTimestamp, coldStartSpan?.endTimestamp);
    });
  });
}

class Fixture {
  final options = SentryFlutterOptions(dsn: fakeDsn);
  final nativeBinding = MockSentryNativeBinding();
  final hub = MockHub();
  final scope = MockScope();

  late final context = SentryTransactionContext(
    'name',
    'op',
    samplingDecision: SentryTracesSamplingDecision(true),
  );

  late final tracer = SentryTracer(
    context,
    hub,
    startTimestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final nativeAppStart = NativeAppStart(
    appStartTime: 0,
    pluginRegistrationTime: 10,
    isColdStart: true,
    nativeSpanTimes: {},
  );

  late final sut = NativeAppStartHandler(nativeBinding);

  // Track the enriched transaction
  SentryTracer? _enrichedTransaction;

  Fixture() {
    when(hub.options).thenReturn(options);
    SentryFlutter.sentrySetupStartTime = DateTime.now().toUtc();
  }

  Future<void> call({required DateTime appStartEnd}) async {
    await sut.call(hub, options, context: context, appStartEnd: appStartEnd);
    // Allow time for async span attachment and other operations to complete
    await Future.delayed(Duration(milliseconds: 100));
  }

  SentryTransaction capturedTransaction() {
    // Return the enriched transaction that was created and enriched with spans
    final transaction = _enrichedTransaction ?? scope.span as SentryTracer?;
    if (transaction == null) {
      throw StateError('No transaction found');
    }
    return SentryTransaction(
      transaction,
      measurements: transaction.measurements,
    );
  }
}

class MockScope extends Mock implements Scope {
  ISentrySpan? _span;

  @override
  ISentrySpan? get span => _span;
  @override
  set span(ISentrySpan? value) {
    _span = value;
  }
}

/// Spy wrapper that intercepts track() calls to capture transaction state
class _FakeTimeToDisplayTracker extends TimeToDisplayTracker {
  final TimeToDisplayTracker _delegate;
  final void Function(ISentrySpan transaction) onTrack;

  _FakeTimeToDisplayTracker(this._delegate, {required this.onTrack})
      : super(options: _delegate.options);

  @override
  SpanId? get transactionId => _delegate.transactionId;

  @override
  set transactionId(SpanId? value) => _delegate.transactionId = value;

  @override
  Future<void> track(ISentrySpan transaction,
      {DateTime? ttidEndTimestamp}) async {
    onTrack(transaction);
    return _delegate.track(transaction, ttidEndTimestamp: ttidEndTimestamp);
  }

  @override
  Future<void> reportFullyDisplayed({SpanId? spanId, DateTime? endTimestamp}) =>
      _delegate.reportFullyDisplayed(
          spanId: spanId, endTimestamp: endTimestamp);
}
