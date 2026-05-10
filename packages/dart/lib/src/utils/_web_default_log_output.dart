import '../protocol/sentry_level.dart';

/// Default log output for web. `dart:developer.log` calls do not surface in
/// the browser dev console, so diagnostic messages would otherwise be
/// silently dropped. This implementation forwards to `print`, which the
/// Flutter Web engine routes to `console.log`.
void defaultLogOutput({
  required String name,
  required SentryLevel level,
  required String message,
  Object? error,
  StackTrace? stackTrace,
}) {
  final buffer = StringBuffer('[$name] [${level.name}] $message');
  if (error != null) {
    buffer.write('\n  error: $error');
  }
  if (stackTrace != null) {
    buffer.write('\n  stack: $stackTrace');
  }
  // ignore: avoid_print
  print(buffer.toString());
}
