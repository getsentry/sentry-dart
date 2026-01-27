import 'package:test/test.dart';
import 'package:sentry/src/telemetry/log/log_level.dart';
import 'package:sentry/src/protocol/sentry_level.dart';

void main() {
  group('SentryLogLevel', () {
    test('toSeverityNumber returns correct values', () {
      expect(SentryLogLevel.trace.toSeverityNumber(), 1);
      expect(SentryLogLevel.debug.toSeverityNumber(), 5);
      expect(SentryLogLevel.info.toSeverityNumber(), 9);
      expect(SentryLogLevel.warn.toSeverityNumber(), 13);
      expect(SentryLogLevel.error.toSeverityNumber(), 17);
      expect(SentryLogLevel.fatal.toSeverityNumber(), 21);
    });
  });

  group('SentryLogLevelExtension', () {
    test('toSentryLevel bridges levels correctly', () {
      expect(SentryLogLevel.trace.toSentryLevel(), SentryLevel.debug);
      expect(SentryLogLevel.debug.toSentryLevel(), SentryLevel.debug);
      expect(SentryLogLevel.info.toSentryLevel(), SentryLevel.info);
      expect(SentryLogLevel.warn.toSentryLevel(), SentryLevel.warning);
      expect(SentryLogLevel.error.toSentryLevel(), SentryLevel.error);
      expect(SentryLogLevel.fatal.toSentryLevel(), SentryLevel.fatal);
    });
  });
}
