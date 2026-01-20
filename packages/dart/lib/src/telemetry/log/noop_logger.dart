import 'dart:async';

import '../../protocol/sentry_attribute.dart';
import '../../scope.dart';
import 'logger.dart';

final class NoOpSentryLogger implements SentryLogger {
  const NoOpSentryLogger();

  static const _formatter = _NoOpSentryLoggerFormatter();

  @override
  FutureOr<void> trace(String body,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> debug(String body,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> info(String body,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> warn(String body,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> error(String body,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> fatal(String body,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  SentryLoggerFormatter get fmt => _formatter;
}

final class _NoOpSentryLoggerFormatter implements SentryLoggerFormatter {
  const _NoOpSentryLoggerFormatter();

  @override
  FutureOr<void> trace(String templateBody, List<dynamic> arguments,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> debug(String templateBody, List<dynamic> arguments,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> info(String templateBody, List<dynamic> arguments,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> warn(String templateBody, List<dynamic> arguments,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> error(String templateBody, List<dynamic> arguments,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  FutureOr<void> fatal(String templateBody, List<dynamic> arguments,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}
}
