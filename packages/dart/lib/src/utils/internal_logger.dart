import 'dart:developer' as dev;

import 'package:meta/meta.dart';

import '../../sentry.dart';

typedef LogOutputFunction = void Function({
  required String name,
  required SentryLevel level,
  required String message,
  Object? error,
  StackTrace? stackTrace,
});

void _defaultLogOutput({
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

/// Lightweight isolate compatible diagnostic logger for the Sentry SDK.
///
/// Logger naming convention:
/// - `sentry_dart` – core dart package
/// - `sentry_flutter` – flutter package
/// - `sentry_<integration>` – integration packages (dio, hive, etc.)
///
/// Each package should have one top-level logger instance.
///
/// All log methods accept [Object] for the message parameter.
/// If the message is a [Function], it will be lazily evaluated.
/// Non-string values are converted via `toString()`.
///
/// Example:
/// ```dart
/// const logger = SentryInternalLogger('sentry_flutter');
///
/// logger.warning('Simple message');
/// logger.debug(() => 'Expensive: ${computeDebugInfo()}'); // Lazy evaluation
/// ```
@internal
class SentryInternalLogger {
  final String _name;

  const SentryInternalLogger(this._name);

  static bool _isEnabled = false;
  static SentryLevel _minLevel = SentryLevel.warning;
  static LogOutputFunction _logOutput = _defaultLogOutput;

  @visibleForTesting
  static bool get isEnabled => _isEnabled;

  @visibleForTesting
  static SentryLevel get minLevel => _minLevel;

  /// Configure logging for the current isolate.
  ///
  /// This needs to be called for each new spawned isolate before logging.
  static void configure({
    required bool isEnabled,
    SentryLevel minLevel = SentryLevel.warning,
    LogOutputFunction? logOutput,
  }) {
    _isEnabled = isEnabled;
    _minLevel = minLevel;
    if (logOutput != null) {
      _logOutput = logOutput;
    }
  }

  static bool _isLoggable(SentryLevel level) {
    return _isEnabled && level.ordinal >= _minLevel.ordinal;
  }

  void debug(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.debug, message, error: error, stackTrace: stackTrace);

  void info(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.info, message, error: error, stackTrace: stackTrace);

  void warning(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.warning, message, error: error, stackTrace: stackTrace);

  void error(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.error, message, error: error, stackTrace: stackTrace);

  void fatal(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.fatal, message, error: error, stackTrace: stackTrace);

  @pragma('vm:prefer-inline')
  void _log(
    SentryLevel level,
    Object message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Guarantee tree-shaking with const kDebugMode
    if (!RuntimeChecker.kDebugMode) return;
    if (!_isLoggable(level)) return;

    if (message is Function) {
      message = (message as Object Function())();
    }

    String finalMessage;
    if (message is String) {
      finalMessage = message;
    } else {
      finalMessage = message.toString();
    }

    _logOutput(
      name: _name,
      level: level,
      message: finalMessage,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Logger for the Sentry Dart SDK.
@internal
const debugLogger = SentryInternalLogger('sentry_dart');
