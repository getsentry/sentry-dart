import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';
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
      _options.transport = Transport(
        options: _options,
        sdkIdentifier: '${sdkName}/${sdkVersion}',
        origin: origin,
      );
    }
  }

  //@visibleForTesting
  SentryOptions _options;

  Random _random;

  /// Reports an [event] to Sentry.io.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    Scope scope,
    dynamic hint,
  }) async {
    event = _processEvent(event, eventProcessors: _options.eventProcessors);

    // dropped by sampling or event processors
    if (event == null) {
      return Future.value(SentryId.empty());
    }

    event = _applyScope(event: event, scope: scope);

    event = event.copyWith(platform: sdkPlatform);

    return _options.transport.send(event);
  }

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

  void close() {
    _options.httpClient?.close();
  }

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

  SentryEvent _applyScope({
    @required SentryEvent event,
    @required Scope scope,
  }) {
    if (scope != null) {
      // Merge the scope transaction.
      if (event.transaction == null) {
        event = event.copyWith(transaction: scope.transaction);
      }

      // Merge the user context.
      if (event.userContext == null) {
        event = event.copyWith(userContext: scope.user);
      }

      // Merge the scope fingerprint.
      if (event.fingerprint == null) {
        event = event.copyWith(fingerprint: scope.fingerprint);
      }

      // Merge the scope breadcrumbs.
      if (event.breadcrumbs == null) {
        event = event.copyWith(breadcrumbs: scope.breadcrumbs);
      }

      // TODO add tests
      // Merge the scope tags.
      event = event.copyWith(
          tags: scope.tags.map((key, value) => MapEntry(key, value))
            ..addAll(event.tags ?? {}));

      // Merge the scope extra.
      event = event.copyWith(
          extra: scope.extra.map((key, value) => MapEntry(key, value))
            ..addAll(event.extra ?? {}));

      // Merge the scope level.
      if (scope.level != null) {
        event = event.copyWith(level: scope.level);
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
