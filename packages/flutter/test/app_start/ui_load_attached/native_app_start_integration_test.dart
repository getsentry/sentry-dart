@TestOn('vm && !windows && !linux')
library;

import 'dart:core';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/app_start/ui_load_attached/native_app_start_handler.dart';
import 'package:sentry_flutter/src/app_start/ui_load_attached/native_app_start_handler_v2.dart';
import 'package:sentry_flutter/src/app_start/ui_load_attached/native_app_start_integration.dart';

import '../../fake_frame_callback_handler.dart';
import '../../mocks.dart';
import '../../mocks.mocks.dart';

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
    rasterFinishWallTime: 10,
  );

  group('$NativeAppStartIntegration', () {
    test('does not add integration if tracing is disabled', () async {
      fixture.options.tracesSampleRate = null;
      fixture.options.tracesSampler = null;

      await fixture.callIntegration();

      expect(
        fixture.options.sdk.integrations,
        isNot(contains(NativeAppStartIntegration.integrationName)),
      );
    });

    test(
      'does not install on iOS when standalone app start tracing is enabled',
      () async {
        fixture.options.platform = MockPlatform.iOS();
        fixture.options.enableStandaloneAppStartTracing = true;

        await fixture.callIntegration();

        expect(fixture.frameCallbackHandler.timingsCallback, isNull);
        expect(
          fixture.options.sdk.integrations,
          isNot(contains(NativeAppStartIntegration.integrationName)),
        );
      },
    );

    test(
      'installs on macOS when standalone app start tracing is enabled',
      () async {
        fixture.options.platform = MockPlatform.macOS();
        fixture.options.enableStandaloneAppStartTracing = true;

        await fixture.callIntegration();

        expect(fixture.frameCallbackHandler.timingsCallback, isNotNull);
        expect(
          fixture.options.sdk.integrations,
          contains(NativeAppStartIntegration.integrationName),
        );
      },
    );

    test('adds integration', () async {
      await fixture.callIntegration();

      expect(
        fixture.options.sdk.integrations,
        contains(NativeAppStartIntegration.integrationName),
      );
    });

    test(
      'does not let an install failure escape into the integration chain',
      () async {
        fixture.options.automatedTestMode = false;
        fixture.frameCallbackHandler.addTimingsCallbackError = StateError(
          'install blew up',
        );

        await expectLater(fixture.callIntegration(), completes);
      },
    );

    test('rethrows an install failure under automatedTestMode', () async {
      fixture.frameCallbackHandler.addTimingsCallbackError = StateError(
        'install blew up',
      );

      await expectLater(fixture.callIntegration(), throwsStateError);
    });

    test('adds timingsCallback', () async {
      await fixture.callIntegration();

      expect(fixture.frameCallbackHandler.timingsCallback, isNotNull);
    });

    test('timingsCallback calls nativeAppStartHandler', () async {
      await fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);

      expect(fixture.nativeAppStartHandler.calls, 1);
      expect(fixture.nativeAppStartHandler.appStartEnd, isNotNull);
      expect(fixture.nativeAppStartHandler.context, isNotNull);
    });

    test('sets correct app start from timing', () async {
      await fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);

      expect(fixture.nativeAppStartHandler.calls, 1);
      expect(fixture.nativeAppStartHandler.appStartEnd, isNotNull);
      expect(
        fixture.nativeAppStartHandler.appStartEnd,
        DateTime.fromMicrosecondsSinceEpoch(10),
      );
    });

    test('handles timingsCallback exactly once', () async {
      await fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);
      timingsCallback([_fakeFrameTiming]);

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
      expect(fixture.nativeAppStartHandler.calls, 1);
    });

    test('handles empty timings', () async {
      await fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      expect(() => timingsCallback([]), throwsA(isA<StateError>()));

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
    });

    test('removes timingsCallback after it was triggered', () async {
      await fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([
        FrameTiming(
          vsyncStart: 10,
          buildStart: 10,
          buildFinish: 10,
          rasterStart: 10,
          rasterFinish: 10,
          rasterFinishWallTime: 10,
        ),
      ]);

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(fixture.frameCallbackHandler.timingsCallback, isNull);
    });

    test('sets root transaction context and ttd transaction ids', () async {
      await fixture.callIntegration();

      final timingsCallback = fixture.frameCallbackHandler.timingsCallback!;
      timingsCallback([_fakeFrameTiming]);

      expect(fixture.nativeAppStartHandler.context, isNotNull);

      expect(fixture.nativeAppStartHandler.context?.name, 'root /');
      expect(
        fixture.nativeAppStartHandler.context?.operation,
        // ignore: invalid_use_of_internal_member
        SentrySpanOperations.uiLoad,
      );
      expect(
        fixture.nativeAppStartHandler.context?.transactionNameSource,
        SentryTransactionNameSource.component,
      );

      expect(
        fixture.options.timeToDisplayTracker.transactionId,
        fixture.nativeAppStartHandler.context?.spanId,
      );
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final hub = MockHub();

  final frameCallbackHandler = FakeFrameCallbackHandler();
  final nativeAppStartHandler = FakeNativeAppStartHandler();
  final nativeAppStartHandlerV2 = FakeNativeAppStartHandlerV2();

  late NativeAppStartIntegration sut = NativeAppStartIntegration(
    frameCallbackHandler,
    nativeAppStartHandler,
    nativeAppStartHandlerV2,
  );

  Fixture() {
    when(hub.options).thenReturn(options);
  }

  Future<void> callIntegration() => sut.call(hub, options);
}

class FakeNativeAppStartHandler implements NativeAppStartHandler {
  SentryTransactionContext? context;
  DateTime? appStartEnd;
  var calls = 0;

  @override
  Future<void> call(
    Hub hub,
    SentryFlutterOptions options, {
    required DateTime? appStartEnd,
    required SentryTransactionContext context,
  }) async {
    this.appStartEnd = appStartEnd;
    this.context = context;
    calls += 1;
  }
}

class FakeNativeAppStartHandlerV2 implements NativeAppStartHandlerV2 {
  DateTime? appStartEnd;
  var calls = 0;

  @override
  Future<void> call(
    Hub hub,
    SentryFlutterOptions options, {
    required DateTime appStartEnd,
  }) async {
    this.appStartEnd = appStartEnd;
    calls += 1;
  }
}
