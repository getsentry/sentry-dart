@TestOn('vm && !windows && !linux')
library;

// ignore_for_file: invalid_use_of_internal_member

import 'dart:core';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/app_start/app_start_info.dart';
import 'package:sentry_flutter/src/app_start/app_start_tracker.dart';
import 'package:sentry_flutter/src/app_start/native_app_start_integration.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
    fixture.options.tracesSampleRate = 1.0;
  });

  final _fakeFrameTiming = FrameTiming(
      vsyncStart: 10,
      buildStart: 10,
      buildFinish: 10,
      rasterStart: 10,
      rasterFinish: 10,
      rasterFinishWallTime: 10);

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

    test('timingsCallback tracks parsed app start info', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.appStartTracker.trackCalls, 1);
      expect(fixture.appStartTracker.appStartInfo, isNotNull);
    });

    test('sets correct app start end from timing', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(
        fixture.appStartTracker.appStartInfo?.end,
        DateTime.fromMicrosecondsSinceEpoch(10),
      );
    });

    test('cancels tracker when native app start is null', () async {
      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenAnswer((_) async => null);
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.appStartTracker.cancelCalls, 1);
      expect(fixture.appStartTracker.trackCalls, 0);
    });

    test('prepares tracker when integration is called', () async {
      fixture.callIntegration();

      expect(fixture.appStartTracker.prepareCalls, 1);
    });

    test('handles timingsCallback exactly once', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
      expect(fixture.appStartTracker.trackCalls, 1);
    });

    test('handles empty timings', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      expect(
        () => timingsCallback([]),
        throwsA(isA<StateError>()),
      );

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
    });

    test('removes timingsCallback after it was triggered', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([
        FrameTiming(
            vsyncStart: 10,
            buildStart: 10,
            buildFinish: 10,
            rasterStart: 10,
            rasterFinish: 10,
            rasterFinishWallTime: 10)
      ]);

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final hub = MockHub();

  final frameCallbackHandler = FakeFrameCallbackHandler();
  final nativeBinding = MockSentryNativeBinding();
  final appStartTracker = FakeAppStartTracker();

  late NativeAppStartIntegration sut = NativeAppStartIntegration(
    frameCallbackHandler,
    nativeBinding,
    appStartTracker,
  );

  Fixture() {
    when(hub.options).thenReturn(options);
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
}

class FakeAppStartTracker implements AppStartTracker {
  var prepareCalls = 0;
  var trackCalls = 0;
  var cancelCalls = 0;
  AppStartInfo? appStartInfo;

  @override
  void prepare(Hub hub, SentryFlutterOptions options) {
    prepareCalls += 1;
  }

  @override
  Future<void> track(
    Hub hub,
    SentryFlutterOptions options,
    AppStartInfo appStartInfo,
  ) async {
    this.appStartInfo = appStartInfo;
    trackCalls += 1;
  }

  @override
  void cancel(SentryFlutterOptions options) {
    cancelCalls += 1;
  }
}
