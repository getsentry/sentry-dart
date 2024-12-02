@TestOn('browser')

import 'dart:html';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('Web SDK Integration', () {
    tearDown(() async {
      await Sentry.close();
    });

    test('Injects script into document head', () async {
      await SentryFlutter.init((options) {
        options.dsn = 'https://abc@def.ingest.sentry.io/1234567';
      });

      final scripts = document
          .querySelectorAll('script')
          .map((script) => script as ScriptElement)
          .toList();

      // should inject the debug script
      expect(scripts.first.src, contains('bundle.tracing.js'));
    });
  });
}
