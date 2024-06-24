import 'dart:async';
import 'dart:math';
import 'package:meta/meta.dart';
import 'utils/stacktrace_utils.dart';
import 'metrics/metric.dart';
import 'metrics/metrics_aggregator.dart';
import 'sentry_baggage.dart';
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
import 'transport/spotlight_http_transport.dart';
import 'transport/task_queue.dart';
import 'utils/isolate_utils.dart';
import 'version.dart';
import 'sentry_envelope.dart';
import 'client_reports/client_report_recorder.dart';
import 'client_reports/discard_reason.dart';
import 'transport/data_category.dart';

/// Default value for [SentryUser.ipAddress]. It gets set when an event does not have
/// a user and IP address. Only applies if [SentryOptions.sendDefaultPii] is set
/// to true.
const _defaultIpAddress = '{{auto}}';

/// Logs crash reports and events to the Sentry.io service.
class SentryClient {
  final SentryOptions _options;
  late final _taskQueue = TaskQueue<SentryId?>(
    _options.maxQueueSize,
    _options.logger,
  );

  final Random? _random;

  late final MetricsAggregator? _metricsAggregator;

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
    if (options.spotlight.enabled) {
      options.transport = SpotlightHttpTransport(options, options.transport);
    }
    return SentryClient._(options);
  }

  /// Instantiates a client using [SentryOptions]
  SentryClient._(this._options)
      : _random = _options.sampleRate == null ? null : Random(),
        _metricsAggregator = _options.enableMetrics
            ? MetricsAggregator(options: _options)
            : null;

  @internal
  MetricsAggregator? get metricsAggregator => _metricsAggregator;

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
      preparedEvent = await scope.applyToEvent(preparedEvent, hint);
    } else {
      _options.logger(
          SentryLevel.debug, 'No scope to apply on event was provided');
    }

    // dropped by scope event processors
    if (preparedEvent == null) {
      return _sentryId;
    }

    preparedEvent = await _runEventProcessors(
      preparedEvent,
      hint,
      eventProcessors: _options.eventProcessors,
    );

    // dropped by event processors
    if (preparedEvent == null) {
      return _sentryId;
    }

    preparedEvent = _createUserOrSetDefaultIpAddress(preparedEvent);

    preparedEvent = await _runBeforeSend(
      preparedEvent,
      hint,
    );

    // dropped by beforeSend
    if (preparedEvent == null) {
      return _sentryId;
    }

    var attachments = List<SentryAttachment>.from(scope?.attachments ?? []);
    attachments.addAll(hint.attachments);
    var screenshot = hint.screenshot;
    if (screenshot != null) {
      attachments.add(screenshot);
    }

    var viewHierarchy = hint.viewHierarchy;
    if (viewHierarchy != null) {
      attachments.add(viewHierarchy);
    }

    var traceContext = scope?.span?.traceContext();
    if (traceContext == null) {
      if (scope?.propagationContext.baggage == null) {
        scope?.propagationContext.baggage =
            SentryBaggage({}, logger: _options.logger);
        scope?.propagationContext.baggage?.setValuesFromScope(scope, _options);
      }
      if (scope != null) {
        traceContext = SentryTraceContextHeader.fromBaggage(
            scope.propagationContext.baggage!);
      }
    }

    final envelope = SentryEnvelope.fromEvent(
      preparedEvent,
      _options.sdk,
      dsn: _options.dsn,
      traceContext: traceContext,
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
      final extractedExceptions = _exceptionFactory.extractor
          .flatten(event.throwableMechanism, stackTrace);

      final sentryExceptions = <SentryException>[];
      final sentryThreads = <SentryThread>[];

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

    // The stacktrace is not part of an exception,
    // therefore add it to the threads.
    // https://develop.sentry.dev/sdk/event-payloads/stacktrace/
    if (stackTrace != null || _options.attachStacktrace) {
      stackTrace ??= getCurrentStackTrace();
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

  SentryEvent _createUserOrSetDefaultIpAddress(SentryEvent event) {
    var user = event.user;
    if (user == null) {
      return event.copyWith(user: SentryUser(ipAddress: _defaultIpAddress));
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

    final hint = Hint();

    if (scope != null) {
      preparedTransaction = await scope.applyToEvent(preparedTransaction, hint)
          as SentryTransaction?;
    } else {
      _options.logger(
          SentryLevel.debug, 'No scope to apply on transaction was provided');
    }

    // dropped by scope event processors
    if (preparedTransaction == null) {
      return _sentryId;
    }

    preparedTransaction = await _runEventProcessors(
      preparedTransaction,
      hint,
      eventProcessors: _options.eventProcessors,
    ) as SentryTransaction?;

    // dropped by event processors
    if (preparedTransaction == null) {
      return _sentryId;
    }

    preparedTransaction =
        await _runBeforeSend(preparedTransaction, hint) as SentryTransaction?;

    // dropped by beforeSendTransaction
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

    final profileInfo = preparedTransaction.tracer.profileInfo;
    if (profileInfo != null) {
      envelope.items.add(profileInfo.asEnvelopeItem());
    }
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

  /// Reports the [metricsBuckets] to Sentry.io.
  Future<SentryId> captureMetrics(
      Map<int, Iterable<Metric>> metricsBuckets) async {
    final envelope = SentryEnvelope.fromMetrics(
      metricsBuckets,
      _options.sdk,
      dsn: _options.dsn,
    );
    final id = await _attachClientReportsAndSend(envelope);
    return id ?? SentryId.empty();
  }

  void close() {
    _metricsAggregator?.close();
    _options.httpClient.close();
  }

  Future<SentryEvent?> _runBeforeSend(
    SentryEvent event,
    Hint hint,
  ) async {
    SentryEvent? eventOrTransaction = event;

    final beforeSend = _options.beforeSend;
    final beforeSendTransaction = _options.beforeSendTransaction;
    String beforeSendName = 'beforeSend';

    try {
      if (event is SentryTransaction && beforeSendTransaction != null) {
        beforeSendName = 'beforeSendTransaction';
        final e = beforeSendTransaction(event);
        if (e is Future<SentryTransaction?>) {
          eventOrTransaction = await e;
        } else {
          eventOrTransaction = e;
        }
      } else if (beforeSend != null) {
        final e = beforeSend(event, hint);
        if (e is Future<SentryEvent?>) {
          eventOrTransaction = await e;
        } else {
          eventOrTransaction = e;
        }
      }
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'The $beforeSendName callback threw an exception',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }

    if (eventOrTransaction == null) {
      _recordLostEvent(event, DiscardReason.beforeSend);
      _options.logger(
        SentryLevel.debug,
        '${event.runtimeType} was dropped by $beforeSendName callback',
      );
    }

    return eventOrTransaction;
  }

  Future<SentryEvent?> _runEventProcessors(
    SentryEvent event,
    Hint hint, {
    required List<EventProcessor> eventProcessors,
  }) async {
    SentryEvent? processedEvent = event;
    for (final processor in eventProcessors) {
      try {
        final e = processor.apply(processedEvent!, hint);
        if (e is Future<SentryEvent?>) {
          processedEvent = await e;
        } else {
          processedEvent = e;
        }
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'An exception occurred while processing event by a processor',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
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

  Future<SentryId?> _attachClientReportsAndSend(SentryEnvelope envelope) {
    final clientReport = _options.recorder.flush();
    envelope.addClientReport(clientReport);
    return _taskQueue.enqueue(
      () => _options.transport.send(envelope),
      SentryId.empty(),
    );
  }
}
