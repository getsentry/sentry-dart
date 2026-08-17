// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/replay/integration.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import '../screenshot/test_widget.dart';

void main() {
  late ReplayIntegration sut;
  late MockSentryNativeBinding native;
  late SentryFlutterOptions options;
  late MockHub hub;

  setUp(() {
    hub = MockHub();
    options = defaultTestOptions();
    native = MockSentryNativeBinding();
    when(native.supportsReplay).thenReturn(true);
    sut = ReplayIntegration(native);
  });

  tearDown(() {
    SentryScreenshotWidget.reset();
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    for (final view in binding.platformDispatcher.views) {
      view.resetPhysicalSize();
    }
  });

  for (var supportsReplay in [true, false]) {
    test(
      '$ReplayIntegration in options.sdk.integrations when supportsReplay=$supportsReplay',
      () {
        when(native.supportsReplay).thenReturn(supportsReplay);
        options.replay.sessionSampleRate = 1.0;
        sut.call(hub, options);
        var matcher = contains(replayIntegrationName);
        matcher = supportsReplay ? matcher : isNot(matcher);
        expect(options.sdk.integrations, matcher);
      },
    );
  }

  for (var sampleRate in [0.5, 0.0]) {
    test(
      '$ReplayIntegration in options.sdk.integrations when sessionSampleRate=$sampleRate',
      () {
        options.replay.sessionSampleRate = sampleRate;
        sut.call(hub, options);
        var matcher = contains(replayIntegrationName);
        matcher = sampleRate > 0 ? matcher : isNot(matcher);
        expect(options.sdk.integrations, matcher);
      },
    );
  }

  group('$ReplayIntegration when an event is about to be sent', () {
    late Scope scope;

    setUp(() {
      scope = Scope(defaultTestOptions());
      options.replay.onErrorSampleRate = 1.0;
      when(
        native.captureReplay(),
      ).thenAnswer((_) async => SentryId.fromId('42'));
      when(hub.configureScope(any)).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.first
                as FutureOr<void> Function(Scope);
        await callback(scope);
      });
    });

    Future<void> send(SentryEvent event, {Hint? hint}) async {
      await sut.call(hub, options);
      await options.lifecycleRegistry.dispatchCallback(
        OnBeforeSendEvent(event, hint ?? Hint()),
      );
    }

    SentryEvent errorEvent() => SentryEvent(
      eventId: SentryId.newId(),
      exceptions: [
        SentryException(
          type: 'type',
          value: 'value',
          mechanism: Mechanism(type: 'foo'),
        ),
      ],
    );

    SentryEvent feedbackEvent() => SentryEvent(
      type: 'feedback',
      contexts: Contexts(feedback: SentryFeedback(message: 'fixture-message')),
    );

    test('captures replay for an error event', () async {
      await send(errorEvent());

      verify(native.captureReplay()).called(1);
      expect(scope.replayId, SentryId.fromId('42'));
    });

    test('does not capture replay for an event without exceptions', () async {
      await send(SentryEvent(eventId: SentryId.newId(), exceptions: []));

      verifyNever(native.captureReplay());
      expect(scope.replayId, isNull);
    });

    test('captures replay for a feedback event', () async {
      await send(feedbackEvent());

      verify(native.captureReplay()).called(1);
      expect(scope.replayId, SentryId.fromId('42'));
    });

    test('does not capture replay for a widget feedback event', () async {
      final hint = Hint()..set(TypeCheckHint.isWidgetFeedback, true);

      await send(feedbackEvent(), hint: hint);

      verifyNever(native.captureReplay());
      expect(scope.replayId, isNull);
    });

    test('does not capture replay when onErrorSampleRate is zero', () async {
      options.replay.onErrorSampleRate = 0.0;
      options.replay.sessionSampleRate = 1.0;

      await send(errorEvent());

      verifyNever(native.captureReplay());
      expect(scope.replayId, isNull);
    });

    test('does not capture replay after the integration is closed', () async {
      await sut.call(hub, options);
      sut.close();

      await options.lifecycleRegistry.dispatchCallback(
        OnBeforeSendEvent(errorEvent(), Hint()),
      );

      verifyNever(native.captureReplay());
    });
  });

  testWidgets('Configures replay when displayed', (tester) async {
    options.replay.sessionSampleRate = 1.0;
    when(native.setReplayConfig(any)).thenReturn(null);
    sut.call(hub, options);

    TestWidgetsFlutterBinding.ensureInitialized();
    await pumpTestElement(tester);
    await tester.pumpAndSettle(Duration(seconds: 1));

    final config =
        verify(native.setReplayConfig(captureAny)).captured.single
            as ReplayConfig;
    expect(config.frameRate, 1);
    expect(config.width, 800);
    expect(config.height, 600);
  });

  testWidgets('Adjusts resolution based on quality', (tester) async {
    options.replay.sessionSampleRate = 1.0;
    options.replay.quality = SentryReplayQuality.low;
    when(native.setReplayConfig(any)).thenReturn(null);
    sut.call(hub, options);

    TestWidgetsFlutterBinding.ensureInitialized();
    await pumpTestElement(tester);
    await tester.pumpAndSettle(Duration(seconds: 1));

    final config =
        verify(native.setReplayConfig(captureAny)).captured.single
            as ReplayConfig;
    expect(config.width, 640);
    expect(config.height, 480);
  });

  testWidgets(
    'Does not call setReplayConfig again when widget size remains unchanged',
    (tester) async {
      options.replay.sessionSampleRate = 1.0;
      when(native.setReplayConfig(any)).thenReturn(null);
      sut.call(hub, options);

      TestWidgetsFlutterBinding.ensureInitialized();

      tester.view.physicalSize = Size(10, 20);
      await pumpTestElement(tester);
      await tester.pumpAndSettle(Duration(seconds: 1));

      tester.view.physicalSize = Size(10, 20);
      await pumpTestElement(tester);
      await tester.pumpAndSettle(Duration(seconds: 1));

      verify(native.setReplayConfig(any)).called(1);
    },
  );

  testWidgets('Does call setReplayConfig again when widget size changed', (
    tester,
  ) async {
    options.replay.sessionSampleRate = 1.0;
    when(native.setReplayConfig(any)).thenReturn(null);
    sut.call(hub, options);

    TestWidgetsFlutterBinding.ensureInitialized();

    tester.view.physicalSize = Size(10, 20);
    await pumpTestElement(tester);
    await tester.pumpAndSettle(Duration(seconds: 1));

    tester.view.physicalSize = Size(20, 20);
    await pumpTestElement(tester);
    await tester.pumpAndSettle(Duration(seconds: 1));

    verify(native.setReplayConfig(any)).called(2);
  });
}
