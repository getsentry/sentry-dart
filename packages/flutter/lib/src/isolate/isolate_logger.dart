import 'dart:developer' as developer;

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// Static logger for Isolates that writes diagnostic messages to `dart:developer.log`.
///
/// Intended for worker/background isolates where a `SentryOptions` instance
/// or hub may not be available. Because Dart statics are isolate-local,
/// you must call [configure] once per isolate before using [log].
class IsolateLogger {
  IsolateLogger._();

  static late bool _debug;
  static late SentryLevel _level;
  static late String _loggerName;
  static bool _isConfigured = false;

  /// Configures this logger for the current isolate.
  ///
  /// Must be called once per isolate before invoking [log].
  /// Throws [StateError] if called more than once without calling [reset] first.
  ///
  /// - [debug]: when false, suppresses all logs except [SentryLevel.fatal].
  /// - [level]: minimum severity threshold (inclusive) when [debug] is true.
  /// - [loggerName]: logger name for the call sites
  static void configure(
      {required bool debug,
      required SentryLevel level,
      required String loggerName}) {
    if (_isConfigured) {
      throw StateError(
          'IsolateLogger.configure has already been called. It can only be configured once per isolate.');
    }
    _debug = debug;
    _level = level;
    _loggerName = loggerName;
    _isConfigured = true;
  }

  /// Resets the logger state to allow reconfiguration.
  ///
  /// This is intended for testing purposes only.
  @visibleForTesting
  static void reset() {
    _isConfigured = false;
  }

  /// Emits a log entry if enabled.
  ///
  /// Messages are forwarded to [developer.log]. The provided [level] is
  /// mapped via [SentryLevel.toDartLogLevel] to a `developer.log` numeric level.
  /// If logging is disabled or [level] is below the configured threshold,
  /// nothing is emitted. [SentryLevel.fatal] is always emitted.
  static void log(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    assert(
        _isConfigured, 'IsolateLogger.configure must be called before logging');
    if (_isEnabled(level)) {
      developer.log(
        '[${level.name}] $message',
        level: level.toDartLogLevel(),
        name: logger ?? _loggerName,
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
