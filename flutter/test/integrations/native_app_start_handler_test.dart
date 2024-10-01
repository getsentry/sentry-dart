@TestOn('vm')
library flutter_test;

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

    when(fixture.hub.configureScope(captureAny)).thenAnswer((_) {});
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

    test('native app start measurement added to first transaction', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );
      final transaction = fixture.capturedTransaction();

      final measurement = transaction.measurements['app_start_cold']!;
      expect(measurement.value, 10);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);
    });

    test('measurements appended', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(10),
      );

      final measurement = SentryMeasurement.warmAppStart(Duration(seconds: 1));

      final transaction = fixture.capturedTransaction().copyWith();
      transaction.measurements[measurement.name] = measurement;

      expect(transaction.measurements.length, 2);
      expect(transaction.measurements.containsKey(measurement.name), true);
    });

    test('native app start measurement not added if more than 60s', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(60001),
      );

      verifyNever(fixture.hub.captureTransaction(
        captureAny,
        traceContext: captureAnyNamed('traceContext'),
      ));
    });

    test(
        'autoAppStart is false and appStartEnd is not set does not add app start measurement',
        () async {
      fixture.options.autoAppStart = false;
      await fixture.call(
        appStartEnd: null,
      );

      final transaction = fixture.capturedTransaction();

      expect(transaction.measurements.isEmpty, true);
      expect(transaction.spans.length,
          1); // Only containing ui.load.initial_display
      expect(transaction.spans[0].context.operation, 'ui.load.initial_display');
    });

    test(
        'autoAppStart is false and appStartEnd is set adds app start measurement',
        () async {
      fixture.options.autoAppStart = false;

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

  Future<void> call({DateTime? appStartEnd}) async {
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
