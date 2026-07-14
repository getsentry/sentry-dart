// ignore_for_file: invalid_use_of_internal_member

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/standalone_app_start_integration.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$StandaloneAppStartIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() async {
      await fixture.sut.close();
    });

    test('installs standalone trace before the first frame', () async {
      await fixture.callIntegration();
      await pumpEventQueue();

      expect(fixture.appStartRoots, hasLength(1));
      expect(fixture.frameHandler.timingsCallback, isNotNull);
    });

    test('records configured standalone feature usage', () async {
      await fixture.callIntegration();

      expect(
        fixture.options.sdk.features,
        contains('standaloneAppStartTracing'),
      );
    });

    test('samples sibling roots independently with one trace ID', () async {
      var samplerCalls = 0;
      fixture.options
        ..tracesSampleRate = null
        ..tracesSampler = (_) {
          samplerCalls++;
          return 1.0;
        };

      await fixture.callIntegration();
      await pumpEventQueue();

      expect(samplerCalls, 2);
      expect(fixture.rootSpans, hasLength(2));
      expect(
        fixture.rootSpans.map((span) => span.context.traceId).toSet(),
        hasLength(1),
      );
    });

    test('processes the first-frame callback exactly once', () async {
      await fixture.callIntegration();
      final callback = fixture.frameHandler.timingsCallback!;

      callback([fixture.frameTiming]);
      callback([fixture.frameTiming]);
      await pumpEventQueue(times: 10);

      expect(fixture.frameHandler.timingsCallback, isNull);
    });

    test('keeps the first-frame callback after empty timings', () async {
      await fixture.callIntegration();
      final callback = fixture.frameHandler.timingsCallback!;

      callback([]);
      await pumpEventQueue();

      expect(fixture.frameHandler.timingsCallback, same(callback));

      callback([fixture.frameTiming]);
      await pumpEventQueue(times: 10);

      expect(fixture.frameHandler.timingsCallback, isNull);
    });

    test('keeps the first-frame callback after stale timings', () async {
      await fixture.callIntegration();
      final callback = fixture.frameHandler.timingsCallback!;

      callback([fixture.frameTimingAt(150000)]);
      await pumpEventQueue();

      expect(fixture.frameHandler.timingsCallback, same(callback));

      callback([fixture.frameTiming]);
      await pumpEventQueue(times: 10);

      expect(fixture.frameHandler.timingsCallback, isNull);
    });

    test('keeps initial display when native timing is invalid', () async {
      when(fixture.native.fetchNativeAppStart()).thenAnswer(
        (_) async => fixture.nativeAppStart(appStartMilliseconds: 1000),
      );

      await fixture.callIntegration();

      expect(fixture.appStartRoots, isEmpty);
      expect(fixture.frameHandler.timingsCallback, isNotNull);
    });

    test('close abandons the standalone trace', () async {
      await fixture.callIntegration();
      await pumpEventQueue();
      final root = fixture.appStartRoots.single;

      await fixture.sut.close();

      expect(root.tracer.finished, isTrue);
      expect(fixture.frameHandler.timingsCallback, isNull);
    });
  });
}

class Fixture {
  final frameHandler = FakeFrameCallbackHandler();
  final native = MockSentryNativeBinding();
  final rootSpans = <SentrySpan>[];
  List<SentrySpan> get appStartRoots =>
      rootSpans.where((span) => span.context.operation == 'app.start').toList();
  final processStart = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final setup = DateTime.fromMillisecondsSinceEpoch(200, isUtc: true);
  final snapshot = DateTime.fromMillisecondsSinceEpoch(300, isUtc: true);
  final frameTiming = FrameTiming(
    vsyncStart: 400000,
    buildStart: 400000,
    buildFinish: 400000,
    rasterStart: 400000,
    rasterFinish: 400000,
    rasterFinishWallTime: 400000,
  );

  FrameTiming frameTimingAt(int microseconds) => FrameTiming(
        vsyncStart: microseconds,
        buildStart: microseconds,
        buildFinish: microseconds,
        rasterStart: microseconds,
        rasterFinish: microseconds,
        rasterFinishWallTime: microseconds,
      );

  late final options = defaultTestOptions(platform: MockPlatform.android())
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.static
    ..enableStandaloneAppStartTracing = true
    ..clock = () => snapshot;
  late final hub = Hub(options);
  late final sut = StandaloneAppStartIntegration(frameHandler, native);

  Fixture() {
    SentryFlutter.sentrySetupStartTime = setup;
    options.lifecycleRegistry.registerCallback<OnSpanStart>((event) {
      if (event.span is SentrySpan && (event.span as SentrySpan).isRootSpan) {
        rootSpans.add(event.span as SentrySpan);
      }
    });
    options.timeToDisplayTracker = TimeToDisplayTracker(
      hub: hub,
      options: options,
    );
    options.timeToDisplayTrackerV2 = TimeToDisplayTrackerV2(
      hub: hub,
      frameCallbackHandler: frameHandler,
    );
    when(native.fetchNativeAppStart()).thenAnswer(
      (_) async => nativeAppStart(),
    );
  }

  NativeAppStart nativeAppStart({int appStartMilliseconds = 0}) =>
      NativeAppStart(
        appStartTime: appStartMilliseconds,
        pluginRegistrationTime: 100,
        isColdStart: true,
        nativeSpanTimes: {},
      );

  Future<void> callIntegration() => sut.call(hub, options);
}
