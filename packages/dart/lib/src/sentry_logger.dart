import 'dart:async';
import 'hub.dart';
import 'hub_adapter.dart';
import 'protocol/sentry_log.dart';
import 'protocol/sentry_log_level.dart';
import 'protocol/sentry_attribute.dart';
import 'sentry_options.dart';
import 'sentry_logger_formatter.dart';

class SentryLogger {
  SentryLogger(this._clock, {Hub? hub}) : _hub = hub ?? HubAdapter();

  final ClockProvider _clock;
  final Hub _hub;

  late final fmt = SentryLoggerFormatter(this);

  FutureOr<void> trace(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.trace, body, attributes: attributes);
  }

  FutureOr<void> debug(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.debug, body, attributes: attributes);
  }

  FutureOr<void> info(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.info, body, attributes: attributes);
  }

  FutureOr<void> warn(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.warn, body, attributes: attributes);
  }

  FutureOr<void> error(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.error, body, attributes: attributes);
  }

  FutureOr<void> fatal(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.fatal, body, attributes: attributes);
  }

  // Helper

  FutureOr<void> _captureLog(
    SentryLogLevel level,
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    final log = SentryLog(
      spanId: _hub.getSpan()?.context.spanId,
      timestamp: _clock(),
      level: level,
      body: body,
      attributes: attributes ?? {},
    );

    _hub.options.log(
      level.toSentryLevel(),
      _formatLogMessage(level, body, attributes ?? {}),
      logger: 'sentry_logger',
    );

    return _hub.captureLog(log);
  }

  /// Format log message with level and attributes
  String _formatLogMessage(
    SentryLogLevel level,
    String body,
    Map<String, SentryAttribute>? attributes,
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
  String _formatAttributeValue(SentryAttribute attribute) {
    switch (attribute.type) {
      case 'string':
        if (attribute.value is String) {
          return '"${attribute.value}"';
        }
        break;
      case 'boolean':
        if (attribute.value is bool) {
          return attribute.value.toString();
        }
        break;
      case 'integer':
        if (attribute.value is int) {
          return attribute.value.toString();
        }
        break;
      case 'double':
        if (attribute.value is double) {
          final value = attribute.value as double;
          // Handle special double values
          if (value.isNaN || value.isInfinite) {
            return value.toString();
          }
          // Ensure doubles always show decimal notation to distinguish from ints
          // Use toStringAsFixed(1) for whole numbers, toString() for decimals
          return value == value.toInt()
              ? value.toStringAsFixed(1)
              : value.toString();
        }
        break;
    }
    return attribute.value.toString();
  }
}
