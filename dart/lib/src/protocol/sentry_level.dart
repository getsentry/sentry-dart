import 'package:meta/meta.dart';

/// Severity of the logged [Event].
@immutable
class SentryLevel {
  const SentryLevel._(this.name, this.ordinal);

  static const fatal = SentryLevel._('fatal', 5);
  static const error = SentryLevel._('error', 4);
  static const warning = SentryLevel._('warning', 3);
  static const info = SentryLevel._('info', 2);
  static const debug = SentryLevel._('debug', 1);

  /// API name of the level as it is encoded in the JSON protocol.
  final String name;
  final int ordinal;

  /// For use with Dart's
  /// [`log`](https://api.dart.dev/stable/2.12.4/dart-developer/log.html)
  /// function.
  /// These levels are inspired by
  /// https://pub.dev/documentation/logging/latest/logging/Level-class.html
  int toLogLevel() {
    switch (this) {
      // Level.SHOUT
      case SentryLevel.fatal:
        return 1200;
      // Level.SEVERE
      case SentryLevel.error:
        return 1000;
      // Level.SEVERE
      case SentryLevel.warning:
        return 900;
      // Level.INFO
      case SentryLevel.info:
        return 800;
      // Level.CONFIG
      case SentryLevel.debug:
        return 700;
    }
    return 700;
  }
}
