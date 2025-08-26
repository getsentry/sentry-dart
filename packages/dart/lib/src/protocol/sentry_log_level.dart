import 'sentry_level.dart';

enum SentryLogLevel {
  trace('trace'),
  debug('debug'),
  info('info'),
  warn('warn'),
  error('error'),
  fatal('fatal');

  final String value;
  const SentryLogLevel(this.value);

  /// For use with Dart's
  /// [`log`](https://api.dart.dev/stable/2.12.4/dart-developer/log.html)
  /// function.
  /// These levels are inspired by
  /// https://pub.dev/documentation/logging/latest/logging/Level-class.html
  int toSeverityNumber() {
    switch (this) {
      case SentryLogLevel.trace:
        return 1;
      case SentryLogLevel.debug:
        return 5;
      case SentryLogLevel.info:
        return 9;
      case SentryLogLevel.warn:
        return 13;
      case SentryLogLevel.error:
        return 17;
      case SentryLogLevel.fatal:
        return 21;
    }
  }
}

/// Extension to bridge SentryLogLevel to SentryLevel
extension SentryLogLevelExtension on SentryLogLevel {
  /// Converts this SentryLogLevel to the corresponding SentryLevel
  /// for use with the diagnostic logging system.
  SentryLevel toSentryLevel() {
    switch (this) {
      case SentryLogLevel.trace:
        return SentryLevel.debug;
      case SentryLogLevel.debug:
        return SentryLevel.debug;
      case SentryLogLevel.info:
        return SentryLevel.info;
      case SentryLogLevel.warn:
        return SentryLevel.warning;
      case SentryLogLevel.error:
        return SentryLevel.error;
      case SentryLogLevel.fatal:
        return SentryLevel.fatal;
    }
  }
}
