import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/web/replay/web_replay_capture_scale.dart';

void main() {
  group('webReplayCaptureScale', () {
    test('low is 0.5', () {
      expect(webReplayCaptureScale(SentryReplayQuality.low), 0.5);
    });

    test('medium is 0.7', () {
      expect(webReplayCaptureScale(SentryReplayQuality.medium), 0.7);
    });

    test('high is 1.0', () {
      expect(webReplayCaptureScale(SentryReplayQuality.high), 1.0);
    });
  });
}
