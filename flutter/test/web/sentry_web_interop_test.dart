@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/sentry_js_bridge.dart';
import 'package:sentry_flutter/src/web/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_web_interop.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('SentryWebInterop', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
      // Clean up existing scripts
      // final existingScripts =
      //     document.querySelectorAll('script[src*="sentry-cdn"]');
      // for (final script in existingScripts) {
      //   script.remove();
      // }
    });

    //
    // group('initialization', () {
    //   test('initializes JS SDK with correct config', () async {
    //     final sut = fixture.getSut();
    //
    //     await sut.init(fixture.options);
    //
    //     final client = sut._jsBridge.getClient();
    //     expect(client, isNotNull);
    //   });
    //
    //   test('configures replay integration', () async {
    //     fixture.options.experimental.replay.sessionSampleRate = 1.0;
    //     final sut = fixture.getSut();
    //
    //     await sut.init(fixture.options);
    //
    //     expect(sut._replay, isNotNull);
    //     final replayId = await sut.getReplayId();
    //     expect(replayId, isNotNull);
    //   });
    //
    //   test('handles script loading failure', () async {
    //     fixture.scriptLoader.failNextLoad();
    //     final sut = fixture.getSut();
    //
    //     await sut.init(fixture.options);
    //
    //     expect(
    //         fixture.options.logger.messages,
    //         contains(predicate<LogMessage>((m) =>
    //             m.level == SentryLevel.warning &&
    //             m.message.contains('cannot initialize Sentry JS SDK'))));
    //   });
    // });
    //
    // group('envelope handling', () {
    //   late SentryWebInterop sut;
    //
    //   setUp(() async {
    //     sut = fixture.getSut();
    //     await sut.init(fixture.options);
    //   });
    //
    //   test('sends envelope to JS SDK', () async {
    //     final envelope = SentryEnvelope(
    //       SentryEnvelopeHeader(SentryId.newId()),
    //       [
    //         SentryEnvelopeItem(
    //           const SentryEnvelopeItemHeader('event'),
    //           SentryEvent(),
    //         ),
    //       ],
    //     );
    //
    //     await sut.captureEnvelope(envelope);
    //
    //     // Verify envelope was sent through JS bridge
    //     verify(fixture.jsBridge.getClient().sendEnvelope(any));
    //   });
    //
    //   test('updates session on error events', () async {
    //     final event = SentryEvent(
    //       exceptions: [Exception('test')],
    //     );
    //
    //     final envelope = SentryEnvelope(
    //       SentryEnvelopeHeader(SentryId.newId()),
    //       [
    //         SentryEnvelopeItem(
    //           const SentryEnvelopeItemHeader('event'),
    //           event,
    //         ),
    //       ],
    //     );
    //
    //     await sut.captureEnvelope(envelope);
    //
    //     final session = fixture.jsBridge.getSession();
    //     expect(session?.errors, 1);
    //   });
    // });

    group('replay', () {
      late SentryWebInterop sut;

      setUp(() async {
        fixture.options.experimental.replay.sessionSampleRate = 1.0;
        sut = fixture.getSut();
        await sut.init(fixture.options);
      });

      test('flushes replay events', () async {
        await sut.flushReplay();

        // Verify flush was called on replay instance
        verify(fixture.jsBridge.replayIntegration(any).flush());
      });

      test('handles missing replay integration', () async {
        fixture.options.experimental.replay.sessionSampleRate = 0;
        final sut = fixture.getSut();
        await sut.init(fixture.options);

        // Should not throw
        await expectLater(sut.flushReplay(), completes);
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final jsBridge = MockSentryJsApi();

  SentryWebInterop getSut() {
    final scriptLoader = SentryScriptLoader(options);
    return SentryWebInterop(jsBridge, options, scriptLoader);
  }
}
