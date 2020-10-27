import 'dart:async';
import 'dart:math';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/noop_transport.dart';

import 'client_stub.dart'
    if (dart.library.html) 'browser_client.dart'
    if (dart.library.io) 'io_client.dart';
import 'protocol.dart';

/// Logs crash reports and events to the Sentry.io service.
abstract class SentryClient {
  /// Creates a new platform appropriate client.
  ///
  /// Creates an `SentryIOClient` if `dart:io` is available and a `SentryBrowserClient` if
  /// `dart:html` is available, otherwise it will throw an unsupported error.
  factory SentryClient(SentryOptions options) => createSentryClient(options);

  SentryClient.base(this._options, {String origin}) {
    _random = _options.sampleRate == null ? null : Random();
    if (_options.transport is NoOpTransport) {
      _options.transport = Transport(options: _options, origin: origin);
    }
  }

  SentryOptions _options;

  Random _random;

  /// Reports an [event] to Sentry.io.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    Scope scope,
    dynamic hint,
  }) async {
    final emptyFuture = Future.value(SentryId.empty());

    event = _processEvent(event, eventProcessors: _options.eventProcessors);

    // dropped by sampling or event processors
    if (event == null) {
      return emptyFuture;
    }

    if (scope != null) {
      event = scope.applyToEvent(event, hint);
    } else {
      _options.logger(SentryLevel.debug, 'No scope is defined');
    }

    // dropped by scope event processors
    if (event == null) {
      return emptyFuture;
    }

    event = _prepareEvent(event);

    if (_options.beforeSendCallback != null) {
      try {
        event = _options.beforeSendCallback(event, hint);
      } catch (err) {
        _options.logger(
          SentryLevel.error,
          'The BeforeSend callback threw an exception',
        );
      }
      if (event == null) {
        _options.logger(SentryLevel.debug, 'Event was dropped by a processor');
        return emptyFuture;
      }
    }

    return _options.transport.send(event);
  }

  SentryEvent _prepareEvent(SentryEvent event) => event.copyWith(
        serverName: event.serverName ?? _options.serverName,
        dist: event.dist ?? _options.dist,
        environment:
            event.environment ?? _options.environment ?? defaultEnvironment,
        release: event.release ?? _options.release,
        sdk: event.sdk ?? _options.sdk,
        platform: event.platform ?? sdkPlatform,
      );

  /// Reports the [throwable] and optionally its [stackTrace] to Sentry.io.
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Scope scope,
    dynamic hint,
  }) {
    final event = SentryEvent(
      exception: throwable,
      stackTrace: stackTrace,
      timestamp: _options.clock(),
    );
    return captureEvent(event, scope: scope, hint: hint);
  }

  /// Reports the [template]
  Future<SentryId> captureMessage(
    String formatted, {
    SentryLevel level = SentryLevel.info,
    String template,
    List<dynamic> params,
    Scope scope,
    dynamic hint,
  }) {
    final event = SentryEvent(
      message: Message(formatted, template: template, params: params),
      level: level,
      timestamp: _options.clock(),
    );

    return captureEvent(event, scope: scope, hint: hint);
  }

  void close() => _options.httpClient?.close();

  SentryEvent _processEvent(
    SentryEvent event, {
    dynamic hint,
    List<EventProcessor> eventProcessors,
  }) {
    if (_sampleRate()) {
      _options.logger(
        SentryLevel.debug,
        'Event ${event.eventId.toString()} was dropped due to sampling decision.',
      );
      return null;
    }

    for (final processor in eventProcessors) {
      try {
        event = processor(event, hint);
      } catch (err) {
        _options.logger(
          SentryLevel.error,
          'An exception occurred while processing event by a processor : $err',
        );
      }
      if (event == null) {
        _options.logger(SentryLevel.debug, 'Event was dropped by a processor');
        break;
      }
    }
    return event;
  }

  bool _sampleRate() {
    if (_options.sampleRate != null && _random != null) {
      return (_options.sampleRate < _random.nextDouble());
    }
    return false;
  }
}
