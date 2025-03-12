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

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  void setupMocks(Fixture fixture) {
    when(fixture.hub.startTransaction(
      'root /',
      'ui.load',
      description: null,
      startTimestamp: anyNamed('startTimestamp'),
    )).thenReturn(fixture.tracer);

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

      final transaction = fixture.capturedTransaction().copyWith();

      final measurement = transaction.measurements['time_to_initial_display']!;
      expect(measurement.value, 10);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);
    });

    test('added transaction has no ttfd measurement', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      final transaction = fixture.capturedTransaction().copyWith();

      final measurement = transaction.measurements['time_to_full_display'];
      expect(measurement, isNull);
    });

    test('added transaction has ttfd measurement if opt in', () async {
      Future.delayed(
        const Duration(milliseconds: 100),
        () async =>
            await fixture.options.timeToDisplayTracker.reportFullyDisplayed(),
      );

      fixture.options.enableTimeToFullDisplayTracing = true;

      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      final transaction = fixture.capturedTransaction().copyWith();

      final measurement = transaction.measurements['time_to_full_display'];
      expect(measurement, isNotNull);
    });

    test('no transaction if app start takes more than 60s', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(60001),
      );

      verifyNever(fixture.hub.captureTransaction(
        captureAny,
        traceContext: captureAnyNamed('traceContext'),
      ));
    });

    test('added transaction is bound to scope', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );
      expect(fixture.scope.setSpans.length, 2);
      expect(fixture.scope.setSpans[0], fixture.tracer);
      expect(fixture.scope.setSpans[1], isNull);
    });

    test('added transaction is not bound to scope if already set', () async {
      final alreadySet = MockSentryTracer();
      fixture.scope.span = alreadySet;
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );
      expect(fixture.scope.setSpans.length, 1);
      expect(fixture.scope.setSpans[0], alreadySet);
    });
  });

  group('App start spans', () {
    late SentrySpan? coldStartSpan,
        pluginRegistrationSpan,
        sentrySetupSpan,
        firstFrameRenderSpan;
    // ignore: invalid_use_of_internal_member
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

  late final tracer = SentryTracer(
    SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(true),
    ),
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

  Fixture() {
    when(hub.options).thenReturn(options);
    SentryFlutter.sentrySetupStartTime = DateTime.now().toUtc();
  }

  Future<void> call({required DateTime appStartEnd}) async {
    await sut.call(hub, options, appStartEnd: appStartEnd);
  }

  SentryTransaction capturedTransaction() {
    final args = verify(hub.captureTransaction(
      captureAny,
      traceContext: captureAnyNamed('traceContext'),
    )).captured;
    return args[0] as SentryTransaction;
  }
}

class MockScope extends Mock implements Scope {
  final setSpans = <ISentrySpan?>[];

  @override
  ISentrySpan? get span => setSpans.lastOrNull;
  @override
  set span(ISentrySpan? value) {
    setSpans.add(value);
  }
}
