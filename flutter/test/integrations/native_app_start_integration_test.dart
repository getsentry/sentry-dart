@TestOn('vm')
library flutter_test;

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';
import 'package:sentry_flutter/src/native/sentry_native.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  void setupMocks(Fixture fixture) {
    when(fixture.hub.startTransaction('root /', 'ui.load',
            description: null, startTimestamp: anyNamed('startTimestamp')))
        .thenReturn(fixture.createTracer());
    when(fixture.hub.configureScope(captureAny)).thenAnswer((_) {});
    when(fixture.hub
            .captureTransaction(any, traceContext: anyNamed('traceContext')))
        .thenAnswer((_) async => SentryId.empty());
  }

  group('$NativeAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      fixture = Fixture();
      setupMocks(fixture);

      NativeAppStartIntegration.clearAppStartInfo();
    });

    test('native app start measurement added to first transaction', () async {
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;

      final measurement = enriched.measurements['app_start_cold']!;
      expect(measurement.value, 10);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);
    });

    test('native app start measurement not added to following transactions',
        () async {
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;

      var enriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;
      var secondEnriched =
          await processor.apply(enriched, Hint()) as SentryTransaction;

      expect(secondEnriched.measurements.length, 1);
    });

    test('measurements appended', () async {
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});
      final measurement = SentryMeasurement.warmAppStart(Duration(seconds: 1));

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer).copyWith();
      transaction.measurements[measurement.name] = measurement;

      final processor = fixture.options.eventProcessors.first;

      var enriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;
      var secondEnriched =
          await processor.apply(enriched, Hint()) as SentryTransaction;

      expect(secondEnriched.measurements.length, 2);
      expect(secondEnriched.measurements.containsKey(measurement.name), true);
    });

    test('native app start measurement not added if more than 60s', () async {
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(60001);
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;

      expect(enriched.measurements.isEmpty, true);
    });

    test('native app start integration is called and sets app start info',
        () async {
      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(10);
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
      expect(appStartInfo?.start, DateTime.fromMillisecondsSinceEpoch(0));
      expect(appStartInfo?.end, DateTime.fromMillisecondsSinceEpoch(10));
    });

    test(
        'autoAppStart is false and appStartEnd is not set does not add app start measurement',
        () async {
      fixture.options.autoAppStart = false;
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;

      expect(enriched.measurements.isEmpty, true);
      expect(enriched.spans.isEmpty, true);
    });

    test(
        'autoAppStart is false and appStartEnd is set adds app start measurement',
        () async {
      fixture.options.autoAppStart = false;
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});
      SentryFlutter.native = fixture.native;

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      SentryFlutter.setAppStartEnd(DateTime.fromMillisecondsSinceEpoch(10));

      final tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);

      final processor = fixture.options.eventProcessors.first;
      final enriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;

      final measurement = enriched.measurements['app_start_cold']!;
      expect(measurement.value, 10);
      expect(measurement.unit, DurationSentryMeasurementUnit.milliSecond);

      final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();

      final appStartSpan = enriched.spans.firstWhereOrNull((element) =>
          element.context.description == appStartInfo!.appStartTypeDescription);
      final pluginRegistrationSpan = enriched.spans.firstWhereOrNull(
          (element) =>
              element.context.description ==
              appStartInfo!.pluginRegistrationDescription);
      final sentrySetupSpan = enriched.spans.firstWhereOrNull((element) =>
          element.context.description == appStartInfo!.sentrySetupDescription);
      final firstFrameRenderSpan = enriched.spans.firstWhereOrNull((element) =>
          element.context.description ==
          appStartInfo!.firstFrameRenderDescription);

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

    final allNativeSpanTimes = {
      ...validNativeSpanTimes,
      ...invalidNativeSpanTimes,
    };

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      fixture = Fixture();
      NativeAppStartIntegration.clearAppStartInfo();

      fixture.native.appStartEnd = DateTime.fromMillisecondsSinceEpoch(50);
      fixture.binding.nativeAppStart = NativeAppStart(
          appStartTime: 0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: allNativeSpanTimes);
      // dartLoadingEnd needs to be set after engine end (see MockNativeChannel)
      SentryFlutter.sentrySetupStartTime =
          DateTime.fromMillisecondsSinceEpoch(15);

      setupMocks(fixture);
      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final processor = fixture.options.eventProcessors.first;
      tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);
      enriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;

      final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();

      coldStartSpan = enriched.spans.firstWhereOrNull((element) =>
          element.context.description == appStartInfo?.appStartTypeDescription);
      pluginRegistrationSpan = enriched.spans.firstWhereOrNull((element) =>
          element.context.description ==
          appStartInfo?.pluginRegistrationDescription);
      sentrySetupSpan = enriched.spans.firstWhereOrNull((element) =>
          element.context.description == appStartInfo?.sentrySetupDescription);
      firstFrameRenderSpan = enriched.spans.firstWhereOrNull((element) =>
          element.context.description ==
          appStartInfo?.firstFrameRenderDescription);
    });

    test('native app start spans not added to following transactions',
        () async {
      final processor = fixture.options.eventProcessors.first;

      final transaction = SentryTransaction(fixture.createTracer());

      final secondEnriched =
          await processor.apply(transaction, Hint()) as SentryTransaction;

      expect(secondEnriched.spans.length, 0);
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
              fixture.binding.nativeAppStart!.appStartTime.toInt())
          .toUtc();
      expect(coldStartSpan?.startTimestamp, appStartTime);
      expect(pluginRegistrationSpan?.startTimestamp, appStartTime);
      expect(sentrySetupSpan?.startTimestamp,
          pluginRegistrationSpan?.endTimestamp);
      expect(
          firstFrameRenderSpan?.startTimestamp, sentrySetupSpan?.endTimestamp);
    });

    test('have correct endTimestamp', () async {
      final engineReadyEndtime = DateTime.fromMillisecondsSinceEpoch(
              fixture.binding.nativeAppStart!.pluginRegistrationTime.toInt())
          .toUtc();
      expect(coldStartSpan?.endTimestamp, fixture.native.appStartEnd?.toUtc());
      expect(pluginRegistrationSpan?.endTimestamp, engineReadyEndtime);
      expect(sentrySetupSpan?.endTimestamp,
          SentryFlutter.sentrySetupStartTime?.toUtc());
      expect(firstFrameRenderSpan?.endTimestamp, coldStartSpan?.endTimestamp);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);
  final binding = MockNativeChannel();
  late final native = SentryNative(options, binding);

  Fixture() {
    native.reset();
    when(hub.options).thenReturn(options);
    SentryFlutter.sentrySetupStartTime = DateTime.now().toUtc();
  }

  NativeAppStartIntegration getNativeAppStartIntegration() {
    return NativeAppStartIntegration(
      native,
      FakeFrameCallbackHandler(),
    );
  }

  // ignore: invalid_use_of_internal_member
  SentryTracer createTracer({
    bool? sampled = true,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(sampled!),
    );
    return SentryTracer(context, hub);
  }
}
