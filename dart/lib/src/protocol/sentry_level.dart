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
}
