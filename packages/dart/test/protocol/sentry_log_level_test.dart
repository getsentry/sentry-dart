import 'package:test/test.dart';
import 'package:sentry/src/protocol/sentry_log_level.dart';
import 'package:sentry/src/protocol/sentry_level.dart';

void main() {
  group('SentryLogLevel', () {
    test('fromName returns correct levels', () {
      expect(SentryLogLevel.fromName('trace'), SentryLogLevel.trace);
      expect(SentryLogLevel.fromName('debug'), SentryLogLevel.debug);
      expect(SentryLogLevel.fromName('info'), SentryLogLevel.info);
      expect(SentryLogLevel.fromName('warn'), SentryLogLevel.warn);
      expect(SentryLogLevel.fromName('error'), SentryLogLevel.error);
      expect(SentryLogLevel.fromName('fatal'), SentryLogLevel.fatal);
      expect(SentryLogLevel.fromName('unknown'), SentryLogLevel.debug);
    });

    test('toSeverityNumber returns correct values', () {
      expect(SentryLogLevel.trace.toSeverityNumber(), 1);
      expect(SentryLogLevel.debug.toSeverityNumber(), 5);
      expect(SentryLogLevel.info.toSeverityNumber(), 9);
      expect(SentryLogLevel.warn.toSeverityNumber(), 13);
      expect(SentryLogLevel.error.toSeverityNumber(), 17);
      expect(SentryLogLevel.fatal.toSeverityNumber(), 21);
    });

    test('properties are correct', () {
      expect(SentryLogLevel.trace.name, 'trace');
      expect(SentryLogLevel.trace.ordinal, 1);
      expect(SentryLogLevel.debug.name, 'debug');
      expect(SentryLogLevel.debug.ordinal, 5);
      expect(SentryLogLevel.info.name, 'info');
      expect(SentryLogLevel.info.ordinal, 9);
      expect(SentryLogLevel.warn.name, 'warn');
      expect(SentryLogLevel.warn.ordinal, 13);
      expect(SentryLogLevel.error.name, 'error');
      expect(SentryLogLevel.error.ordinal, 17);
      expect(SentryLogLevel.fatal.name, 'fatal');
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
