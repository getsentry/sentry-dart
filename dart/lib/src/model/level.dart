import 'package:meta/meta.dart';

/// Severity of the logged [Event].
@immutable
class SeverityLevel {
  const SeverityLevel._(this.name);

  static const fatal = SeverityLevel._('fatal');
  static const error = SeverityLevel._('error');
  static const warning = SeverityLevel._('warning');
  static const info = SeverityLevel._('info');
  static const debug = SeverityLevel._('debug');

  /// API name of the level as it is encoded in the JSON protocol.
  final String name;
}
