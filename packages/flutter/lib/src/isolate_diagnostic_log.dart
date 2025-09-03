import 'dart:developer' as developer;

import '../sentry_flutter.dart';

class IsolateDiagnosticLog {
  IsolateDiagnosticLog._();

  static late final bool _debug;
  static late final SentryLevel _level;

  static void configure({required bool debug, required SentryLevel level}) {
    _debug = debug;
    _level = level;
  }

  static void log(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (_isEnabled(level)) {
      developer.log(
        '[${level.name}] $message',
        level: level.toDartLogLevel(),
        name: logger ?? 'sentry',
        time: DateTime.now(),
        error: exception,
        stackTrace: stackTrace,
      );
    }
  }

  static bool _isEnabled(SentryLevel level) {
    return _debug && level.ordinal >= _level.ordinal ||
        level == SentryLevel.fatal;
  }
}
