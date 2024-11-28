// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/replay_event_processor.dart';
import 'package:sentry_flutter/src/replay/integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

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

  for (var supportsReplay in [true, false]) {
    test(
        '$ReplayIntegration in options.sdk.integrations when supportsReplay=$supportsReplay',
        () {
      when(native.supportsReplay).thenReturn(supportsReplay);
      options.experimental.replay.sessionSampleRate = 1.0;
      sut.call(hub, options);
      var matcher = contains(replayIntegrationName);
      matcher = supportsReplay ? matcher : isNot(matcher);
      expect(options.sdk.integrations, matcher);
    });
  }

  for (var sampleRate in [0.5, 0.0]) {
    test(
        '$ReplayIntegration in options.sdk.integrations when sessionSampleRate=$sampleRate',
        () {
      options.experimental.replay.sessionSampleRate = sampleRate;
      sut.call(hub, options);
      var matcher = contains(replayIntegrationName);
      matcher = sampleRate > 0 ? matcher : isNot(matcher);
      expect(options.sdk.integrations, matcher);
    });
  }

  for (var sampleRate in [0.5, 0.0]) {
    test(
        '$ReplayEventProcessor in options.EventProcessors when onErrorSampleRate=$sampleRate',
        () async {
      options.experimental.replay.onErrorSampleRate = sampleRate;
      await sut.call(hub, options);

      if (sampleRate > 0) {
        expect(
            options.eventProcessors, anyElement(isA<ReplayEventProcessor>()));
      } else {
        expect(options.eventProcessors, isEmpty);
      }
    });
  }
}
