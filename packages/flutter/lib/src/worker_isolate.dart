import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

class WorkerConfig {
  final SendPort hostPort;
  final Map<String, Object?> environment;

  const WorkerConfig({required this.hostPort, required this.environment});
}

abstract class WorkerIsolate {
  @protected
  final SendPort hostPort;

  @protected
  final Map<String, Object?> environment;

  WorkerIsolate(WorkerConfig config)
      : hostPort = config.hostPort,
        environment = config.environment;
}

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
