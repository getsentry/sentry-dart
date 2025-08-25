import 'package:meta/meta.dart';
import 'sentry_level.dart';

/// Severity of the logged [Event].
@immutable
class SentryLogLevel {
  const SentryLogLevel._(this.name, this.ordinal);

  static const trace = SentryLogLevel._('trace', 1);
  static const debug = SentryLogLevel._('debug', 5);
  static const info = SentryLogLevel._('info', 9);
  static const warn = SentryLogLevel._('warn', 13);
  static const error = SentryLogLevel._('error', 17);
  static const fatal = SentryLogLevel._('fatal', 21);

  /// API name of the level as it is encoded in the JSON protocol.
  final String name;
  final int ordinal;

  factory SentryLogLevel.fromName(String name) {
    switch (name) {
      case 'fatal':
        return SentryLogLevel.fatal;
      case 'error':
        return SentryLogLevel.error;
      case 'warn':
        return SentryLogLevel.warn;
      case 'info':
        return SentryLogLevel.info;
      case 'debug':
        return SentryLogLevel.debug;
      case 'trace':
        return SentryLogLevel.trace;
    }
    return SentryLogLevel.debug;
  }

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
    throw StateError('Unreachable code');
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
    throw StateError('Unreachable code');
  }
}
