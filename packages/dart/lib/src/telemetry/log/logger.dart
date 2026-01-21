import 'dart:async';

import '../../../sentry.dart';

// TODO(major-v10): refactor FutureOr to void

/// Interface for emitting custom logs to Sentry.
///
/// Access via [Sentry.logger].
abstract interface class SentryLogger {
  /// Logs a message at TRACE level.
  FutureOr<void> trace(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a message at DEBUG level.
  FutureOr<void> debug(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a message at INFO level.
  FutureOr<void> info(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a message at WARN level.
  FutureOr<void> warn(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a message at ERROR level.
  FutureOr<void> error(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a message at FATAL level.
  FutureOr<void> fatal(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Provides formatted logging with template strings.
  SentryLoggerFormatter get fmt;
}

/// Interface for formatted logging with template strings.
///
/// Access via [SentryLogger.fmt].
abstract interface class SentryLoggerFormatter {
  /// Logs a formatted message at TRACE level.
  FutureOr<void> trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a formatted message at DEBUG level.
  FutureOr<void> debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a formatted message at INFO level.
  FutureOr<void> info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a formatted message at WARN level.
  FutureOr<void> warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a formatted message at ERROR level.
  FutureOr<void> error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });

  /// Logs a formatted message at FATAL level.
  FutureOr<void> fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  });
}
