import 'dart:developer' as dev;

import '../protocol/sentry_level.dart';

/// Default log output for non-web platforms. Uses `dart:developer.log` which
/// integrates with Dart DevTools and the Flutter / IDE log views.
void defaultLogOutput({
  required String name,
  required SentryLevel level,
  required String message,
  Object? error,
  StackTrace? stackTrace,
}) {
  dev.log(
    '[${level.name}] $message',
    name: name,
    level: level.toDartLogLevel(),
    error: error,
    stackTrace: stackTrace,
    time: DateTime.now(),
  );
}
