import 'dart:async';
import 'hub.dart';
import 'hub_adapter.dart';
import 'protocol/sentry_log.dart';
import 'protocol/sentry_log_level.dart';
import 'protocol/sentry_log_attribute.dart';
import 'sentry_options.dart';
import 'sentry_logger_formatter.dart';

class SentryLogger {
  SentryLogger(this._clock, this._log, {Hub? hub}) : _hub = hub ?? HubAdapter();

  final ClockProvider _clock;
  final SdkLogCallback _log;
  final Hub _hub;

  late final fmt = SentryLoggerFormatter(this);

  FutureOr<void> trace(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.trace, body, attributes: attributes);
  }

  FutureOr<void> debug(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.debug, body, attributes: attributes);
  }

  FutureOr<void> info(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.info, body, attributes: attributes);
  }

  FutureOr<void> warn(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.warn, body, attributes: attributes);
  }

  FutureOr<void> error(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.error, body, attributes: attributes);
  }

  FutureOr<void> fatal(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.fatal, body, attributes: attributes);
  }

  // Helper

  FutureOr<void> _captureLog(
    SentryLogLevel level,
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    final log = SentryLog(
      timestamp: _clock(),
      level: level,
      body: body,
      attributes: attributes ?? {},
    );

    _log(
      level.toSentryLevel(),
      _formatLogMessage(level, body, attributes),
      logger: 'sentry_logger',
    );

    return _hub.captureLog(log);
  }

  /// Format log message with level and attributes
  String _formatLogMessage(
    SentryLogLevel level,
    String body,
    Map<String, SentryLogAttribute>? attributes,
  ) {
    if (attributes == null || attributes.isEmpty) {
      return body;
    }

    final attrsStr = attributes.entries
        .map((e) => '"${e.key}": ${_formatAttributeValue(e.value)}')
        .join(', ');

    return '$body {$attrsStr}';
  }

  /// Format attribute value based on its type
  String _formatAttributeValue(SentryLogAttribute attribute) {
    switch (attribute.type) {
      case 'string':
        return '"${attribute.value}"';
      case 'boolean':
        return attribute.value.toString();
      case 'integer':
        return attribute.value.toString();
      case 'double':
        return attribute.value.toString();
      default:
        return '"${attribute.value}"';
    }
  }
}
