import '../../../sentry.dart';

/// Interface for emitting custom logs to Sentry.
///
/// Access via [Sentry.logger].
abstract interface class SentryLogger {
  /// Logs a message at TRACE level.
  void trace(
    String body, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a message at DEBUG level.
  void debug(
    String body, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a message at INFO level.
  void info(
    String body, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a message at WARN level.
  void warn(
    String body, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a message at ERROR level.
  void error(
    String body, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a message at FATAL level.
  void fatal(
    String body, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Provides formatted logging with template strings.
  SentryLoggerFormatter get fmt;
}

/// Interface for formatted logging with template strings.
///
/// Access via [SentryLogger.fmt].
abstract interface class SentryLoggerFormatter {
  /// Logs a formatted message at TRACE level.
  void trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a formatted message at DEBUG level.
  void debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a formatted message at INFO level.
  void info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a formatted message at WARN level.
  void warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a formatted message at ERROR level.
  void error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Logs a formatted message at FATAL level.
  void fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  });
}
