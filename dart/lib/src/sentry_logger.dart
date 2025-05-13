import 'dart:async';
import 'hub.dart';
import 'hub_adapter.dart';
import 'protocol/sentry_log.dart';
import 'protocol/sentry_log_level.dart';
import 'protocol/sentry_log_attribute.dart';
import 'sentry_options.dart';

class SentryLogger {
  SentryLogger(this._clock, {Hub? hub}) : _hub = hub ?? HubAdapter();

  final ClockProvider _clock;
  final Hub _hub;

  Future<void> trace(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.trace, body, attributes: attributes);
  }

  Future<void> debug(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.debug, body, attributes: attributes);
  }

  Future<void> info(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.info, body, attributes: attributes);
  }

  Future<void> warn(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.warn, body, attributes: attributes);
  }

  Future<void> error(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.error, body, attributes: attributes);
  }

  Future<void> fatal(
    String body, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _captureLog(SentryLogLevel.fatal, body, attributes: attributes);
  }

  // Helper

  Future<void> _captureLog(
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
    return _hub.captureLog(log);
  }
}
