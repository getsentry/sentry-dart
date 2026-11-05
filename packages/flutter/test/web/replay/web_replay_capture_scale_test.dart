import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/replay/web_replay_capture_scale.dart';

void main() {
  group('webReplayCaptureScale', () {
    test('returns 0.5 for low', () {
      expect(webReplayCaptureScale(SentryReplayQuality.low), 0.5);
    });

    test('returns 0.7 for medium', () {
      expect(webReplayCaptureScale(SentryReplayQuality.medium), 0.7);
    });

    test('returns 1.0 for high', () {
      expect(webReplayCaptureScale(SentryReplayQuality.high), 1.0);
    });
  });
}
