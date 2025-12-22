import 'dart:developer' as dev;

import 'package:meta/meta.dart';

import 'protocol/sentry_level.dart';

/// Lightweight diagnostic logger for the Sentry SDK.
///
/// Static methods control global (per-isolate) configuration.
/// Instance methods provide per-package logging with a stable prefix.
///
/// Note: Static state is per-isolate (Dart isolates don't share statics).
///
/// Logger naming convention:
/// - `sentry` – core dart package
/// - `sentry.flutter` – flutter package
/// - `sentry.{integration}` – integration packages (dio, hive, etc.)
/// - Use `category:` parameter for sub-areas (e.g., `logger.debug('...', category: 'frames')`)
///
/// Example:
/// ```dart
/// const sentryDebugLogger = SentryDebugLogger('sentry.flutter');
///
/// // Results in logger name: `sentry.flutter:navigation_observer`
/// sentryDebugLogger.warning('My Message', category: 'navigation_observer')
///```
class SentryDebugLogger {
  static bool _enabled = false;
  static SentryLevel _minLevel = SentryLevel.warning;

  /// Configure logging for the current isolate.
  static void configure({
    required bool enabled,
    SentryLevel minLevel = SentryLevel.warning,
  }) {
    _enabled = enabled;
    _minLevel = minLevel;
  }

  /// Snapshot current config for passing to a new isolate.
  static ({bool enabled, String minLevel}) configSnapshot() =>
      (enabled: _enabled, minLevel: _minLevel.name);

  final String name;

  const SentryDebugLogger(this.name);

  void debug(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.debug, message,
          category: category, error: error, stackTrace: stackTrace);

  void info(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.info, message,
          category: category, error: error, stackTrace: stackTrace);

  void warning(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.warning, message,
          category: category, error: error, stackTrace: stackTrace);

  void error(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.error, message,
          category: category, error: error, stackTrace: stackTrace);

  void fatal(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(SentryLevel.fatal, message,
          category: category, error: error, stackTrace: stackTrace);

  @pragma('vm:prefer-inline')
  void _log(
    SentryLevel level,
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enabled) return;
    if (level.ordinal < _minLevel.ordinal) return;

    final logName = _composeName(name, category);
    dev.log(
      message,
      name: logName,
      level: level.toDartLogLevel(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  @pragma('vm:prefer-inline')
  static String _composeName(String prefix, String? category) {
    if (category == null) return prefix;
    final c = category.trim();
    if (c.isEmpty) return prefix;
    return '$prefix.$c';
  }
}

/// Default logger for the Sentry SDK.
@internal
const debugLogger = SentryDebugLogger('sentry');
