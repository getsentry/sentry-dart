@TestOn('vm && !windows && !linux')
library;

// ignore_for_file: invalid_use_of_internal_member

import 'dart:core';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/app_start/native_app_start_integration.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

final _fakeFrameTiming = FrameTiming(
    vsyncStart: 10,
    buildStart: 10,
    buildFinish: 10,
    rasterStart: 10,
    rasterFinish: 10,
    rasterFinishWallTime: 10);

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$NativeAppStartIntegration', () {
    test('does not add integration if tracing is disabled', () {
      fixture.options.tracesSampleRate = null;
      fixture.options.tracesSampler = null;

      fixture.callIntegration();

      expect(fixture.options.sdk.integrations,
          isNot(contains(NativeAppStartIntegration.integrationName)));
    });

    test('adds integration', () async {
      fixture.callIntegration();

      expect(fixture.options.sdk.integrations,
          contains(NativeAppStartIntegration.integrationName));
    });

    test('adds timingsCallback', () async {
      fixture.callIntegration();

      expect(fixture.frameCallbackHandler.timingsCallback, isNotNull);
    });

    test('adds standaloneAppStartTracing feature when enabled', () {
      fixture.options.enableStandaloneAppStartTracing = true;

      fixture.callIntegration();

      expect(fixture.options.sdk.features,
          contains(SentryFeatures.standaloneAppStartTracing));
    });

    test('does not add standaloneAppStartTracing feature when disabled', () {
      fixture.options.enableStandaloneAppStartTracing = false;

      fixture.callIntegration();

      expect(fixture.options.sdk.features,
          isNot(contains(SentryFeatures.standaloneAppStartTracing)));
    });

    test('tracks native app start from the first frame timing', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      fixture.options.enableStandaloneAppStartTracing = true;
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      expect(fixture.findSpanByName('App Start'), isNotNull);
    });

    test('static attached mode writes app start under ui.load', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.static;
      fixture.options.enableStandaloneAppStartTracing = false;
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      final uiLoad = fixture.scopeBoundTracer()!;
      expect(uiLoad.name, 'root /');
      expect(uiLoad.measurements['app_start_cold']?.value, 0);
      expect(uiLoad.findChild('Cold Start'), isNotNull);
      expect(
        uiLoad.findChildByOperation(
          SentrySpanOperations.uiTimeToInitialDisplay,
        ),
        isNotNull,
      );
    });

    test('static standalone mode keeps app start off ui.load', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.static;
      fixture.options.enableStandaloneAppStartTracing = true;
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      final uiLoad = fixture.scopeBoundTracer()!;
      expect(uiLoad.measurements['app_start_cold'], isNull);
      expect(uiLoad.findChild('Cold Start'), isNull);
      expect(
        uiLoad.findChildByOperation(
          SentrySpanOperations.uiTimeToInitialDisplay,
        ),
        isNotNull,
      );

      final appStart = await fixture.capturedTransactionPayload('App Start');
      expect(appStart['transaction'], 'App Start');
      expect(
          appStart['contexts']['trace']['op'], SentrySpanOperations.appStart);
    });

    test('static invalid data is a no-op', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.static;
      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenAnswer((_) async => null);
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      expect(fixture.scopeBoundTracer(), isNull);
      expect(fixture.fakeTransport.envelopes, isEmpty);
    });

    test('static thrown error is a no-op when automatedTestMode is false',
        () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.static;
      fixture.options.automatedTestMode = false;
      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenThrow(Exception('native error'));
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      expect(fixture.scopeBoundTracer(), isNull);
      expect(fixture.fakeTransport.envelopes, isEmpty);
    });

    test('stream attached mode writes app start under ui.load', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      fixture.options.enableStandaloneAppStartTracing = false;
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      final uiLoad = fixture.findSpanByName('root /')!;
      expect(fixture.findSpanByName('App Start'), isNull);
      expect(fixture.findSpanByName('Cold Start')?.parentSpan, same(uiLoad));
      expect(
        fixture.findSpanByName('root / initial display')?.parentSpan,
        same(uiLoad),
      );
    });

    test('stream standalone mode keeps app start off ui.load', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      fixture.options.enableStandaloneAppStartTracing = true;
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      final uiLoad = fixture.findSpanByName('root /')!;
      final appStart = fixture.findSpanByName('App Start')!;
      expect(appStart.parentSpan, isNull);
      expect(fixture.findSpanByName('Cold Start'), isNull);
      expect(
        fixture.findSpanByName('root / initial display')?.parentSpan,
        same(uiLoad),
      );
    });

    test('sets correct app start end from timing', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      fixture.options.enableStandaloneAppStartTracing = true;
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      expect(
        fixture.findSpanByName('App Start')?.endTimestamp,
        DateTime.fromMicrosecondsSinceEpoch(10).toUtc(),
      );
    });

    test('cancels prepared stream route when fetching native app start throws',
        () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      fixture.options.automatedTestMode = false;
      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenThrow(Exception('native error'));
      fixture.callIntegration();
      fixture.timeToDisplayTrackerV2.cancelledRoutes = 0;

      await fixture.dispatchFirstFrameTiming();

      expect(fixture.timeToDisplayTrackerV2.cancelledRoutes, 1);
      expect(fixture.findSpanByName('Cold Start'), isNull);
    });

    test(
        'cancels prepared stream route when native app start data is unavailable',
        () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenAnswer((_) async => null);
      fixture.callIntegration();
      fixture.timeToDisplayTrackerV2.cancelledRoutes = 0;

      await fixture.dispatchFirstFrameTiming();

      expect(fixture.timeToDisplayTrackerV2.cancelledRoutes, 1);
      expect(fixture.findSpanByName('Cold Start'), isNull);
    });

    test('does not drop static ui.load while standalone capture is blocked',
        () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.static;
      fixture.options.enableStandaloneAppStartTracing = true;
      final gate = Completer<SentryId?>();
      fixture.fakeTransport.gate = gate;
      fixture.callIntegration();

      fixture.frameCallbackHandler.timingsCallback!([_fakeFrameTiming]);
      await pumpEventQueue();

      final uiLoad = fixture.scopeBoundTracer()!;
      expect(
        uiLoad.findChildByOperation(
          SentrySpanOperations.uiTimeToInitialDisplay,
        ),
        isNotNull,
      );

      gate.complete(SentryId.empty());
      await pumpEventQueue(times: 20);
    });

    test('handles timingsCallback exactly once', () async {
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      fixture.options.enableStandaloneAppStartTracing = true;
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);

      await pumpEventQueue(times: 20);

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
      expect(
        fixture.capturedSpans.where((span) => span.name == 'App Start'),
        hasLength(1),
      );
    });

    test('handles empty timings', () async {
      fixture.options.automatedTestMode = false;
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([]);
      await pumpEventQueue(times: 20);

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
    });

    test('removes timingsCallback after it was triggered', () async {
      fixture.callIntegration();

      await fixture.dispatchFirstFrameTiming();

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
    });

    test('close removes timingsCallback', () {
      fixture.callIntegration();
      expect(fixture.frameCallbackHandler.timingsCallback, isNotNull);

      fixture.sut.close();

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
    });

    test('does not track when timingsCallback fires after close', () async {
      fixture.callIntegration();
      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;

      fixture.sut.close();
      timingsCallback([_fakeFrameTiming]);
      await pumpEventQueue(times: 20);

      expect(fixture.hub.scope.span, isNull);
    });
  });
}

class Fixture {
  final frameCallbackHandler = FakeFrameCallbackHandler();
  final nativeBinding = MockSentryNativeBinding();
  final fakeTransport = _FakeTransport();
  final capturedSpans = <RecordingSentrySpanV2>[];

  late final SentryFlutterOptions options;
  late final Hub hub;
  late final _RecordingTimeToDisplayTrackerV2 timeToDisplayTrackerV2;
  late NativeAppStartIntegration sut = NativeAppStartIntegration(
    frameCallbackHandler,
    nativeBinding,
  );

  Fixture() {
    options = defaultTestOptions()..tracesSampleRate = 1.0;
    options.transport = fakeTransport;
    hub = Hub(options);
    options.timeToDisplayTracker = TimeToDisplayTracker(
      hub: hub,
      options: options,
    );
    timeToDisplayTrackerV2 = _RecordingTimeToDisplayTrackerV2(
      hub: hub,
      frameCallbackHandler: frameCallbackHandler,
    );
    options.timeToDisplayTrackerV2 = timeToDisplayTrackerV2;
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      if (event.span case final RecordingSentrySpanV2 span) {
        capturedSpans.add(span);
      }
    });
    SentryFlutter.sentrySetupStartTime = DateTime.fromMicrosecondsSinceEpoch(5);
    when(nativeBinding.fetchNativeAppStart()).thenAnswer(
      (_) async => NativeAppStart(
        appStartTime: 0,
        pluginRegistrationTime: 0,
        isColdStart: true,
        nativeSpanTimes: {},
      ),
    );
  }

  void callIntegration() {
    sut.call(hub, options);
  }

  Future<void> dispatchFirstFrameTiming() async {
    frameCallbackHandler.timingsCallback!([_fakeFrameTiming]);
    await pumpEventQueue(times: 20);
  }

  RecordingSentrySpanV2? findSpanByName(String name) {
    for (final span in capturedSpans) {
      if (span.name == name) {
        return span;
      }
    }
    return null;
  }

  SentryTracer? scopeBoundTracer() {
    return hub.scope.span as SentryTracer?;
  }

  Future<Map<String, dynamic>> capturedTransactionPayload(String name) async {
    for (final envelope in fakeTransport.envelopes) {
      for (final item in envelope.items) {
        final data = await item.dataFactory();
        final decoded = jsonDecode(utf8.decode(data));
        if (decoded is Map<String, dynamic> && decoded['transaction'] == name) {
          return decoded;
        }
      }
    }
    throw StateError('No captured transaction named $name');
  }
}

class _RecordingTimeToDisplayTrackerV2 extends TimeToDisplayTrackerV2 {
  _RecordingTimeToDisplayTrackerV2({
    required Hub hub,
    required FakeFrameCallbackHandler frameCallbackHandler,
  }) : super(hub: hub, frameCallbackHandler: frameCallbackHandler);

  var cancelledRoutes = 0;

  @override
  void cancelCurrentRoute() {
    cancelledRoutes += 1;
    super.cancelCurrentRoute();
  }
}

class _FakeTransport implements Transport {
  final envelopes = <SentryEnvelope>[];
  Completer<SentryId?>? gate;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    final gate = this.gate;
    if (gate != null) {
      return gate.future;
    }
    return SentryId.empty();
  }
}

extension on SentryTracer {
  SentrySpan? findChild(String description) {
    return children.firstWhereOrNull(
      (span) => span.context.description == description,
    );
  }

  SentrySpan? findChildByOperation(String operation) {
    return children.firstWhereOrNull(
      (span) => span.context.operation == operation,
    );
  }
}
