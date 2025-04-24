@TestOn('vm')
library;

import 'dart:core';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_handler.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  final _fakeFrameTiming = FrameTiming(
      vsyncStart: 10,
      buildStart: 10,
      buildFinish: 10,
      rasterStart: 10,
      rasterFinish: 10,
      rasterFinishWallTime: 10);

  group('$NativeAppStartIntegration', () {
    test('adds integration', () async {
      fixture.callIntegration();

      expect(
          fixture.options.sdk.integrations
              .contains('nativeAppStartIntegration'),
          true);
    });

    test('adds timingsCallback', () async {
      fixture.callIntegration();

      expect(fixture.frameCallbackHandler.timingsCallback, isNotNull);
    });

    test('timingsCallback calls nativeAppStartHandler', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);

      expect(fixture.nativeAppStartHandler.calls, 1);
      expect(fixture.nativeAppStartHandler.appStartEnd, isNotNull);
    });

    test('sets correct app start from timing', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);

      expect(fixture.nativeAppStartHandler.calls, 1);
      expect(fixture.nativeAppStartHandler.appStartEnd, isNotNull);
      expect(fixture.nativeAppStartHandler.appStartEnd,
          DateTime.fromMicrosecondsSinceEpoch(10));
    });

    test('handles timingsCallback exactly once', () async {
      fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
      expect(fixture.nativeAppStartHandler.calls, 1);
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
  final nativeAppStartHandler = FakeNativeAppStartHandler();

  late NativeAppStartIntegration sut = NativeAppStartIntegration(
    frameCallbackHandler,
    nativeAppStartHandler,
  );

  Fixture() {
    when(hub.options).thenReturn(options);
  }

  void callIntegration() {
    sut.call(hub, options);
  }
}

class FakeNativeAppStartHandler implements NativeAppStartHandler {
  DateTime? appStartEnd;
  var calls = 0;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options,
      {required DateTime? appStartEnd}) async {
    this.appStartEnd = appStartEnd;
    calls += 1;
  }
}
