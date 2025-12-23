import 'dart:developer' as dev;

import 'package:meta/meta.dart';

import '../../sentry.dart';

/// Lightweight isolate compatible diagnostic logger for the Sentry SDK.
///
/// Logger naming convention:
/// - `sentry` – core dart package
/// - `sentry.flutter` – flutter package
/// - `sentry.{integration}` – integration packages (dio, hive, etc.)
///
/// Each package should have at least one top-level instance.
///
/// Example:
/// ```dart
/// const debugLogger = SentryDebugLogger('sentry.flutter');
///
/// debugLogger.warning('My Message')
///```
@internal
class SentryDebugLogger {
  final String _name;

  const SentryDebugLogger(this._name);

  static bool _isEnabled = false;
  static SentryLevel _minLevel = SentryLevel.warning;

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
  }) {
    _isEnabled = isEnabled;
    _minLevel = minLevel;
  }

  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.debug, message, error: error, stackTrace: stackTrace);

  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.info, message, error: error, stackTrace: stackTrace);

  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.warning, message, error: error, stackTrace: stackTrace);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.error, message, error: error, stackTrace: stackTrace);

  void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.fatal, message, error: error, stackTrace: stackTrace);

  @pragma('vm:prefer-inline')
  void _log(
    SentryLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled) return;
    if (level.ordinal < _minLevel.ordinal) return;

    dev.log(
      '[${level.name}] $message',
      name: _name,
      level: level.toDartLogLevel(),
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
    );
  }
}

/// Logger for the Sentry Dart SDK.
@internal
const debugLogger = SentryDebugLogger('sentry');
