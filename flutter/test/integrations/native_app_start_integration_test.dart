@TestOn('vm')
library flutter_test;

import 'dart:core';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_handler.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_integration.dart';

import '../mock_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('$NativeAppStartIntegration adds integration', () async {
    fixture.callIntegration();

    expect(
        fixture.options.sdk.integrations.contains('nativeAppStartIntegration'),
        true);
  });

  test('$NativeAppStartIntegration adds postFrameCallback', () async {
    fixture.callIntegration();

    expect(fixture.frameCallbackHandler.postFrameCallback, isNotNull);
  });

  test(
      '$NativeAppStartIntegration postFrameCallback calls nativeAppStartHandler',
      () async {
    fixture.callIntegration();

    final appStartEnd = DateTime.fromMicrosecondsSinceEpoch(50);
    fixture.sut.appStartEnd = appStartEnd;

    final postFrameCallback = fixture.frameCallbackHandler.postFrameCallback!;
    postFrameCallback(Duration(seconds: 0));

    expect(fixture.nativeAppStartHandler.calls, 1);
    expect(fixture.nativeAppStartHandler.appStartEnd, appStartEnd);
  });

  test(
      '$NativeAppStartIntegration with disabled auto app start waits until appStartEnd is set',
      () async {
    fixture.options.autoAppStart = false;

    fixture.callIntegration();
    final postFrameCallback = fixture.frameCallbackHandler.postFrameCallback!;
    postFrameCallback(Duration(seconds: 0));

    expect(fixture.nativeAppStartHandler.calls, 0);

    final appStartEnd = DateTime.fromMicrosecondsSinceEpoch(50);
    fixture.sut.appStartEnd = appStartEnd;

    await Future<void>.delayed(Duration(milliseconds: 10));

    expect(fixture.frameCallbackHandler.postFrameCallback, isNotNull);
    expect(fixture.nativeAppStartHandler.calls, 1);
    expect(fixture.nativeAppStartHandler.appStartEnd, appStartEnd);
  });

  test(
      '$NativeAppStartIntegration with disabled auto app start waits until timeout',
      () async {
    fixture.options.autoAppStart = false;

    fixture.callIntegration();
    final postFrameCallback = fixture.frameCallbackHandler.postFrameCallback!;
    postFrameCallback(Duration(seconds: 0));

    expect(fixture.nativeAppStartHandler.calls, 0);

    await Future<void>.delayed(Duration(seconds: 11));

    expect(fixture.frameCallbackHandler.postFrameCallback, isNotNull);
    expect(fixture.nativeAppStartHandler.calls, 0);
    expect(fixture.nativeAppStartHandler.appStartEnd, null);
  });
}

class Fixture {
  final options = SentryFlutterOptions(dsn: fakeDsn);
  final hub = MockHub();

  final frameCallbackHandler = MockFrameCallbackHandler();
  final nativeAppStartHandler = MockNativeAppStartHandler();

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

class MockNativeAppStartHandler implements NativeAppStartHandler {
  DateTime? appStartEnd;
  var calls = 0;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options,
      {required DateTime? appStartEnd}) async {
    this.appStartEnd = appStartEnd;
    calls += 1;
  }
}
