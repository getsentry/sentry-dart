import 'package:test/test.dart';
import 'package:sentry/src/protocol/sentry_log_level.dart';
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

    test('properties are correct', () {
      expect(SentryLogLevel.trace.value, 'trace');
      expect(SentryLogLevel.trace.ordinal, 1);
      expect(SentryLogLevel.debug.value, 'debug');
      expect(SentryLogLevel.debug.ordinal, 5);
      expect(SentryLogLevel.info.value, 'info');
      expect(SentryLogLevel.info.ordinal, 9);
      expect(SentryLogLevel.warn.value, 'warn');
      expect(SentryLogLevel.warn.ordinal, 13);
      expect(SentryLogLevel.error.value, 'error');
      expect(SentryLogLevel.error.ordinal, 17);
      expect(SentryLogLevel.fatal.value, 'fatal');
      expect(SentryLogLevel.fatal.ordinal, 21);
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
