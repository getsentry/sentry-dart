import 'dart:async';
import 'dart:math';
import 'package:meta/meta.dart';
import 'sentry_attachment/sentry_attachment.dart';

import 'event_processor.dart';
import 'hint.dart';
import 'sentry_trace_context_header.dart';
import 'sentry_user_feedback.dart';
import 'transport/rate_limiter.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_exception_factory.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'transport/http_transport.dart';
import 'transport/noop_transport.dart';
import 'utils/isolate_utils.dart';
import 'version.dart';
import 'sentry_envelope.dart';
import 'client_reports/client_report_recorder.dart';
import 'client_reports/discard_reason.dart';
import 'transport/data_category.dart';

/// Default value for [User.ipAddress]. It gets set when an event does not have
/// a user and IP address. Only applies if [SentryOptions.sendDefaultPii] is set
/// to true.
const _defaultIpAddress = '{{auto}}';

/// Logs crash reports and events to the Sentry.io service.
class SentryClient {
  final SentryOptions _options;

  final Random? _random;

  static final _sentryId = Future.value(SentryId.empty());

  SentryExceptionFactory get _exceptionFactory => _options.exceptionFactory;

  SentryStackTraceFactory get _stackTraceFactory => _options.stackTraceFactory;

  /// Instantiates a client using [SentryOptions]
  factory SentryClient(SentryOptions options) {
    if (options.sendClientReports) {
      options.recorder = ClientReportRecorder(options.clock);
    }
    if (options.transport is NoOpTransport) {
      final rateLimiter = RateLimiter(options);
      options.transport = HttpTransport(options, rateLimiter);
    }
    return SentryClient._(options);
  }

  /// Instantiates a client using [SentryOptions]
  SentryClient._(this._options)
      : _random = _options.sampleRate == null ? null : Random();

  /// Reports an [event] to Sentry.io.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    Scope? scope,
    dynamic stackTrace,
    Hint? hint,
  }) async {
    if (_sampleRate()) {
      _recordLostEvent(event, DiscardReason.sampleRate);
      _options.logger(
        SentryLevel.debug,
        'Event ${event.eventId.toString()} was dropped due to sampling decision.',
      );
      return _sentryId;
    }

    SentryEvent? preparedEvent = _prepareEvent(event, stackTrace: stackTrace);

    hint ??= Hint();

    if (scope != null) {
      preparedEvent = await scope.applyToEvent(preparedEvent, hint: hint);
    } else {
      _options.logger(
          SentryLevel.debug, 'No scope to apply on event was provided');
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
      final beforeSendEvent = preparedEvent;
      try {
        preparedEvent = await beforeSend(preparedEvent, hint: hint);
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'The BeforeSend callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
      if (preparedEvent == null) {
        _recordLostEvent(beforeSendEvent, DiscardReason.beforeSend);
        _options.logger(
          SentryLevel.debug,
          'Event was dropped by BeforeSend callback',
        );
        return _sentryId;
      }
    }

    if (_options.platformChecker.platform.isAndroid &&
        _options.enableScopeSync) {
      /*
      We do this to avoid duplicate breadcrumbs on Android as sentry-android applies the breadcrumbs
      from the native scope onto every envelope sent through it. This scope will contain the breadcrumbs
      sent through the scope sync feature. This causes duplicate breadcrumbs.
      We then remove the breadcrumbs in all cases but if it is handled == false,
      this is a signal that the app would crash and android would lose the breadcrumbs by the time the app is restarted to read
      the envelope.
      */
      preparedEvent = _eventWithRemovedBreadcrumbsIfHandled(preparedEvent);
    }

    var attachments = List<SentryAttachment>.from(scope?.attachments ?? []);
    var screenshot = hint.screenshot;
    if (screenshot != null) {
      attachments.add(screenshot);
    }

    final envelope = SentryEnvelope.fromEvent(
      preparedEvent,
      _options.sdk,
      dsn: _options.dsn,
      traceContext: scope?.span?.traceContext(),
      attachments: attachments.isNotEmpty ? attachments : null,
    );

    final id = await captureEnvelope(envelope);
    return id ?? SentryId.empty();
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

    if (event is SentryTransaction) {
      return event;
    }

    if (event.exceptions?.isNotEmpty ?? false) {
      return event;
    }

    final isolateName = getIsolateName();
    // Isolates have no id, so the hashCode of the name will be used as id
    final isolateId = isolateName?.hashCode;

    if (event.throwableMechanism != null) {
      final throwable = event.throwable;
      final extractedExceptions = _options.extractor.flatten(throwable, stackTrace);

      var sentryExceptions = <SentryException>[];
      var sentryThreads = <SentryThread>[];

      for (final extractedException in extractedExceptions) {
        var sentryException = _exceptionFactory.getSentryException(
          extractedException.exception,
          stackTrace: extractedException.stackTrace,
        );

        SentryThread? sentryThread;

        if (!_options.platformChecker.isWeb &&
            isolateName != null &&
            _options.attachThreads) {
          sentryException = sentryException.copyWith(threadId: isolateId);
          sentryThread = SentryThread(
            id: isolateId,
            name: isolateName,
            crashed: true,
            current: true,
          );
        }

        sentryExceptions.add(sentryException);
        if (sentryThread != null) {
          sentryThreads.add(sentryThread);
        }
      }

      return event.copyWith(
        exceptions: [...?event.exceptions, ...sentryExceptions],
        threads: [
          ...?event.threads,
          ...sentryThreads,
        ],
      );
    }

    // TODO How to handle boxed cause with stacktrace only?

    // The stacktrace is not part of an exception,
    // therefore add it to the threads.
    // https://develop.sentry.dev/sdk/event-payloads/stacktrace/
    if (stackTrace != null || _options.attachStacktrace) {
      stackTrace ??= StackTrace.current;
      final frames = _stackTraceFactory.getStackFrames(stackTrace);

      if (frames.isNotEmpty) {
        event = event.copyWith(threads: [
          ...?event.threads,
          SentryThread(
            name: isolateName,
            id: isolateId,
            crashed: false,
            current: true,
            stacktrace: SentryStackTrace(frames: frames),
          ),
        ]);
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
    Hint? hint,
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
    Hint? hint,
  }) {
    final event = SentryEvent(
      message: SentryMessage(formatted, template: template, params: params),
      level: level ?? SentryLevel.info,
      timestamp: _options.clock(),
    );

    return captureEvent(event, scope: scope, hint: hint);
  }

  @internal
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
    SentryTraceContextHeader? traceContext,
  }) async {
    SentryTransaction? preparedTransaction =
        _prepareEvent(transaction) as SentryTransaction;

    if (scope != null) {
      preparedTransaction =
          await scope.applyToEvent(preparedTransaction) as SentryTransaction?;
    } else {
      _options.logger(
          SentryLevel.debug, 'No scope to apply on transaction was provided');
    }

    // dropped by scope event processors
    if (preparedTransaction == null) {
      return _sentryId;
    }

    preparedTransaction = await _processEvent(
      preparedTransaction,
      eventProcessors: _options.eventProcessors,
    ) as SentryTransaction?;

    // dropped by event processors
    if (preparedTransaction == null) {
      return _sentryId;
    }

    final attachments = scope?.attachments
        .where((element) => element.addToTransactions)
        .toList();
    final envelope = SentryEnvelope.fromTransaction(
      preparedTransaction,
      _options.sdk,
      dsn: _options.dsn,
      traceContext: traceContext,
      attachments: attachments,
    );
    final id = await captureEnvelope(envelope);

    return id ?? SentryId.empty();
  }

  /// Reports the [envelope] to Sentry.io.
  Future<SentryId?> captureEnvelope(SentryEnvelope envelope) {
    return _attachClientReportsAndSend(envelope);
  }

  /// Reports the [userFeedback] to Sentry.io.
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) {
    final envelope = SentryEnvelope.fromUserFeedback(
      userFeedback,
      _options.sdk,
      dsn: _options.dsn,
    );
    return _attachClientReportsAndSend(envelope);
  }

  void close() => _options.httpClient.close();

  Future<SentryEvent?> _processEvent(
    SentryEvent event, {
    Hint? hint,
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
          exception: exception,
          stackTrace: stackTrace,
        );
      }
      if (processedEvent == null) {
        _recordLostEvent(event, DiscardReason.eventProcessor);
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

  void _recordLostEvent(SentryEvent event, DiscardReason reason) {
    DataCategory category;
    if (event is SentryTransaction) {
      category = DataCategory.transaction;
    } else {
      category = DataCategory.error;
    }
    _options.recorder.recordLostEvent(reason, category);
  }

  SentryEvent _eventWithRemovedBreadcrumbsIfHandled(SentryEvent event) {
    final mechanisms =
        (event.exceptions ?? []).map((e) => e.mechanism).whereType<Mechanism>();
    final hasNoMechanism = mechanisms.isEmpty;
    final hasOnlyHandledMechanism =
        mechanisms.every((e) => (e.handled ?? true));

    if (hasNoMechanism || hasOnlyHandledMechanism) {
      return event.copyWith(breadcrumbs: []);
    } else {
      return event;
    }
  }

  Future<SentryId?> _attachClientReportsAndSend(SentryEnvelope envelope) {
    final clientReport = _options.recorder.flush();
    envelope.addClientReport(clientReport);
    return _options.transport.send(envelope);
  }
}
