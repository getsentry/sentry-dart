import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('Replay recording', () {
    setUp(() async {
      await SentryFlutter.init((options) {
        // ignore: invalid_use_of_internal_member
        options.automatedTestMode = true;
        options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
        options.debug = true;
        options.experimental.replay.sessionSampleRate = 1.0;
      });
    });

    tearDown(() async {
      await Sentry.close();
    });

    test('native binding is initialized', () async {
      // ignore: invalid_use_of_internal_member
      expect(SentryFlutter.native, isNotNull);
    });

    test('session replay is captured', () async {
      // TODO add when the beforeSend callback is implemented for replays.
    });

    test('replay is captured on errors', () async {
      // TODO we may need an HTTP server for this because Android sends replays
      // in a separate envelope.
    });
  },
      skip: Platform.isAndroid
          ? false
          : "Replay recording is not supported on this platform");
}
