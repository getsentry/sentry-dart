import 'dart:async';
import 'dart:math';

import 'event_processor.dart';
import 'transport/rate_limiter.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_exception_factory.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'transport/http_transport.dart';
import 'transport/noop_transport.dart';
import 'version.dart';
import 'sentry_envelope.dart';

/// Default value for [User.ipAddress]. It gets set when an event does not have
/// a user and IP address. Only applies if [SentryOptions.sendDefaultPii] is set
/// to true.
const _defaultIpAddress = '{{auto}}';

/// Logs crash reports and events to the Sentry.io service.
class SentryClient {
  final SentryOptions _options;

  final Random? _random;

  static final _sentryId = Future.value(SentryId.empty());

  late SentryExceptionFactory _exceptionFactory;

  late SentryStackTraceFactory _stackTraceFactory;

  /// Instantiates a client using [SentryOptions]
  factory SentryClient(SentryOptions options) {
    if (options.transport is NoOpTransport) {
      options.transport = HttpTransport(options, RateLimiter(options.clock));
    }

    return SentryClient._(options);
  }

  /// Instantiates a client using [SentryOptions]
  SentryClient._(this._options)
      : _random = _options.sampleRate == null ? null : Random() {
    _stackTraceFactory = SentryStackTraceFactory(_options);
    _exceptionFactory = SentryExceptionFactory(
      _options,
      _stackTraceFactory,
    );
  }

  /// Reports an [event] to Sentry.io.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    Scope? scope,
    dynamic stackTrace,
    dynamic hint,
  }) async {
    if (_sampleRate()) {
      _options.logger(
        SentryLevel.debug,
        'Event ${event.eventId.toString()} was dropped due to sampling decision.',
      );
      return _sentryId;
    }

    SentryEvent? preparedEvent = _prepareEvent(event, stackTrace: stackTrace);

    if (scope != null) {
      preparedEvent = await scope.applyToEvent(preparedEvent, hint);
    } else {
      _options.logger(SentryLevel.debug, 'No scope is defined');
    }

    // dropped by scope event processors
    if (preparedEvent == null) {
      return _sentryId;
    }

    preparedEvent = await _processEvent(
      preparedEvent,
      eventProcessors: _options.eventProcessors,
      hint: hint,
    );

    // dropped by event processors
    if (preparedEvent == null) {
      return _sentryId;
    }

    final beforeSend = _options.beforeSend;
    if (beforeSend != null) {
      try {
        preparedEvent = await beforeSend(preparedEvent, hint: hint);
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'The BeforeSend callback threw an exception',
          error: exception,
          stackTrace: stackTrace,
        );
      }
      if (preparedEvent == null) {
        _options.logger(
          SentryLevel.debug,
          'Event was dropped by BeforeSend callback',
        );
        return _sentryId;
      }
    }
    final envelope = SentryEnvelope.fromEvent(preparedEvent, _options.sdk);
    return await _options.transport.send(envelope);
  }

  SentryEvent _prepareEvent(SentryEvent event, {dynamic stackTrace}) {
    event = event.copyWith(
      serverName: event.serverName ?? _options.serverName,
      dist: event.dist ?? _options.dist,
      environment: event.environment ?? _options.environment,
      release: event.release ?? _options.release,
      sdk: event.sdk ?? _options.sdk,
      platform: event.platform ?? sdkPlatform(_options.platformChecker.isWeb),
    );

    event = _applyDefaultPii(event);

    if (event.exception != null) return event;

    if (event.throwableMechanism != null) {
      final sentryException = _exceptionFactory
          .getSentryException(event.throwableMechanism, stackTrace: stackTrace);

      return event.copyWith(exception: sentryException);
    }

    if (stackTrace != null || _options.attachStacktrace) {
      stackTrace ??= StackTrace.current;
      final frames = _stackTraceFactory.getStackFrames(stackTrace);

      if (frames.isNotEmpty) {
        event = event.copyWith(stackTrace: SentryStackTrace(frames: frames));
      }
    }

    return event;
  }

  /// This modifies the users IP address according
  /// to [SentryOptions.sendDefaultPii].
  SentryEvent _applyDefaultPii(SentryEvent event) {
    if (!_options.sendDefaultPii) {
      return event;
    }
    var user = event.user;
    if (user == null) {
      user = SentryUser(ipAddress: _defaultIpAddress);
      return event.copyWith(user: user);
    } else if (event.user?.ipAddress == null) {
      return event.copyWith(user: user.copyWith(ipAddress: _defaultIpAddress));
    }

    return event;
  }

  /// Reports the [throwable] and optionally its [stackTrace] to Sentry.io.
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Scope? scope,
    dynamic hint,
  }) {
    final event = SentryEvent(
      throwable: throwable,
      timestamp: _options.clock(),
    );

    return captureEvent(
      event,
      stackTrace: stackTrace,
      scope: scope,
      hint: hint,
    );
  }

  /// Reports the [template]
  Future<SentryId> captureMessage(
    String formatted, {
    SentryLevel? level,
    String? template,
    List<dynamic>? params,
    Scope? scope,
    dynamic hint,
  }) {
    final event = SentryEvent(
      message: SentryMessage(formatted, template: template, params: params),
      level: level ?? SentryLevel.info,
      timestamp: _options.clock(),
    );

    return captureEvent(event, scope: scope, hint: hint);
  }

  /// Reports the [envelope] to Sentry.io.
  Future<SentryId?> captureEnvelope(SentryEnvelope envelope) {
    return _options.transport.send(envelope);
  }

  void close() => _options.httpClient.close();

  Future<SentryEvent?> _processEvent(
    SentryEvent event, {
    dynamic hint,
    required List<EventProcessor> eventProcessors,
  }) async {
    SentryEvent? processedEvent = event;
    for (final processor in eventProcessors) {
      try {
        processedEvent = await processor.apply(processedEvent!, hint: hint);
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'An exception occurred while processing event by a processor',
          error: exception,
          stackTrace: stackTrace,
        );
      }
      if (processedEvent == null) {
        _options.logger(SentryLevel.debug, 'Event was dropped by a processor');
        break;
      }
    }
    return processedEvent;
  }

  bool _sampleRate() {
    if (_options.sampleRate != null && _random != null) {
      return (_options.sampleRate! < _random!.nextDouble());
    }
    return false;
  }
}
