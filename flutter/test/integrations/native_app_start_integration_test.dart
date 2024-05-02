@TestOn('vm')
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
  group('$NativeAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      fixture = Fixture();
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
  });

  group('App start spans', () {
    late SentrySpan? coldStartSpan,
        pluginRegistrationSpan,
        mainIsolateSetupSpan,
        firstFrameRenderSpan;
    // ignore: invalid_use_of_internal_member
    late SentryTracer tracer;
    late Fixture fixture;
    late SentryTransaction enrichedTransaction;
    final nativeSpanTimes = {
      'correct span description': {
        'startTimestampMsSinceEpoch': 1,
        'stopTimestampMsSinceEpoch': 2,
      },
      'failing span with null timestamp': {
        'startTimestampMsSinceEpoch': null,
        'stopTimestampMsSinceEpoch': 3,
      },
      'failing span with string timestamp': {
        'startTimestampMsSinceEpoch': '1',
        'stopTimestampMsSinceEpoch': 3,
      },
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
          nativeSpanTimes: nativeSpanTimes);
      // dartLoadingEnd needs to be set after engine end (see MockNativeChannel)
      SentryFlutter.mainIsolateStartTime =
          DateTime.fromMillisecondsSinceEpoch(15);

      fixture.getNativeAppStartIntegration().call(fixture.hub, fixture.options);

      final processor = fixture.options.eventProcessors.first;
      tracer = fixture.createTracer();
      final transaction = SentryTransaction(tracer);
      enrichedTransaction =
          await processor.apply(transaction, Hint()) as SentryTransaction;

      final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();

      coldStartSpan = enrichedTransaction.spans.firstWhereOrNull((element) =>
          element.context.description == appStartInfo?.appStartTypeDescription);
      pluginRegistrationSpan = enrichedTransaction.spans.firstWhereOrNull(
          (element) =>
              element.context.description ==
              appStartInfo?.pluginRegistrationDescription);
      mainIsolateSetupSpan = enrichedTransaction.spans.firstWhereOrNull(
          (element) =>
              element.context.description ==
              appStartInfo?.mainIsolateSetupDescription);
      firstFrameRenderSpan = enrichedTransaction.spans.firstWhereOrNull(
          (element) =>
              element.context.description ==
              appStartInfo?.firstFrameRenderDescription);
    });

    test('properly includes native spans with valid timestamps', () async {
      final spans = enrichedTransaction.spans
          .where((element) => element.data['native'] == true);

      expect(spans.length, 1,
          reason: 'Should only include spans with valid timestamps');
      final nativeSpan = spans.first;

      expect(nativeSpan.context.description, 'correct span description');
      expect(nativeSpan.startTimestamp, isNotNull);
      expect(nativeSpan.endTimestamp, isNotNull);
    });

    test('ignores spans with invalid start timestamps', () async {
      final spans = enrichedTransaction.spans
          .where((element) => element.data['native'] == true);

      expect(spans, isNot(contains('failing span')),
          reason: 'Should not include spans with invalid start timestamps');
    });

    test('are added by event processor', () async {
      expect(coldStartSpan, isNotNull);
      expect(pluginRegistrationSpan, isNotNull);
      expect(mainIsolateSetupSpan, isNotNull);
      expect(firstFrameRenderSpan, isNotNull);
    });

    test('have correct op', () async {
      const op = 'app.start.cold';
      expect(coldStartSpan?.context.operation, op);
      expect(pluginRegistrationSpan?.context.operation, op);
      expect(mainIsolateSetupSpan?.context.operation, op);
      expect(firstFrameRenderSpan?.context.operation, op);
    });

    test('have correct parents', () async {
      expect(coldStartSpan?.context.parentSpanId, tracer.context.spanId);
      expect(pluginRegistrationSpan?.context.parentSpanId,
          coldStartSpan?.context.spanId);
      expect(mainIsolateSetupSpan?.context.parentSpanId,
          coldStartSpan?.context.spanId);
      expect(firstFrameRenderSpan?.context.parentSpanId,
          coldStartSpan?.context.spanId);
    });

    test('have correct traceId', () async {
      final traceId = tracer.context.traceId;
      expect(coldStartSpan?.context.traceId, traceId);
      expect(pluginRegistrationSpan?.context.traceId, traceId);
      expect(mainIsolateSetupSpan?.context.traceId, traceId);
      expect(firstFrameRenderSpan?.context.traceId, traceId);
    });

    test('have correct startTimestamp', () async {
      final appStartTime = DateTime.fromMillisecondsSinceEpoch(
              fixture.binding.nativeAppStart!.appStartTime.toInt())
          .toUtc();
      expect(coldStartSpan?.startTimestamp, appStartTime);
      expect(pluginRegistrationSpan?.startTimestamp, appStartTime);
      expect(mainIsolateSetupSpan?.startTimestamp,
          pluginRegistrationSpan?.endTimestamp);
      expect(firstFrameRenderSpan?.startTimestamp,
          mainIsolateSetupSpan?.endTimestamp);
    });

    test('have correct endTimestamp', () async {
      final engineReadyEndtime = DateTime.fromMillisecondsSinceEpoch(
              fixture.binding.nativeAppStart!.pluginRegistrationTime.toInt())
          .toUtc();
      expect(coldStartSpan?.endTimestamp, fixture.native.appStartEnd?.toUtc());
      expect(pluginRegistrationSpan?.endTimestamp, engineReadyEndtime);
      expect(mainIsolateSetupSpan?.endTimestamp,
          SentryFlutter.mainIsolateStartTime.toUtc());
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
