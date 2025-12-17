import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

import 'client_reports/client_report_recorder.dart';
import 'client_reports/discard_reason.dart';
import 'event_processor/run_event_processors.dart';
import 'hint.dart';
import 'sdk_lifecycle_hooks.dart';
import 'protocol.dart';
import 'protocol/sentry_feedback.dart';
import 'scope.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_baggage.dart';
import 'sentry_envelope.dart';
import 'sentry_exception_factory.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'sentry_trace_context_header.dart';
import 'telemetry_processing/telemetry_buffer.dart';
import 'telemetry_processing/telemetry_processor.dart';
import 'transport/client_report_transport.dart';
import 'transport/data_category.dart';
import 'transport/http_transport.dart';
import 'transport/noop_transport.dart';
import 'transport/rate_limiter.dart';
import 'transport/spotlight_http_transport.dart';
import 'type_check_hint.dart';
import 'utils/isolate_utils.dart';
import 'utils/regex_utils.dart';
import 'utils/stacktrace_utils.dart';
import 'utils.dart';
import 'sentry_log_batcher.dart';
import 'version.dart';

/// Default value for [SentryUser.ipAddress]. It gets set when an event does not have
/// a user and IP address. Only applies if [SentryOptions.sendDefaultPii] is set
/// to true.
const _defaultIpAddress = '{{auto}}';

@visibleForTesting
String get defaultIpAddress => _defaultIpAddress;

/// Logs crash reports and events to the Sentry.io service.
class SentryClient {
  final SentryOptions _options;
  final Random? _random;

  static final _emptySentryId = Future.value(SentryId.empty());

  SentryExceptionFactory get _exceptionFactory => _options.exceptionFactory;
  SentryStackTraceFactory get _stackTraceFactory => _options.stackTraceFactory;

  /// Instantiates a client using [SentryOptions]
  factory SentryClient(SentryOptions options) {
    if (options.sendClientReports) {
      options.recorder = ClientReportRecorder(options.clock);
    }
    RateLimiter? rateLimiter;
    if (options.transport is NoOpTransport) {
      rateLimiter = RateLimiter(options);
      options.transport = HttpTransport(options, rateLimiter);
    }
    // rateLimiter is null if FileSystemTransport is active since Native SDKs take care of rate limiting
    options.transport = ClientReportTransport(
      rateLimiter,
      options,
      options.transport,
    );
    // TODO: Use spotlight integration directly through JS SDK, then we can remove isWeb check
    final enableFlutterSpotlight = (options.spotlight.enabled &&
        (options.platform.isWeb ||
            options.platform.isLinux ||
            options.platform.isWindows));
    // Spotlight in the Flutter layer is only enabled for Web, Linux and Windows
    // Other platforms use spotlight through their native SDKs
    if (enableFlutterSpotlight) {
      options.transport = SpotlightHttpTransport(options, options.transport);
    }
    if (options.enableLogs) {
      options.logBatcher = SentryLogBatcher(options);
    }
    options.telemetryProcessor = DefaultTelemetryProcessor(options.log,
        logBuffer: InMemoryTelemetryBuffer(),
        spanBuffer: InMemoryTelemetryBuffer());
    // TODO(next-pr): remove log batcher
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
    if (_isIgnoredError(event)) {
      _options.log(
        SentryLevel.debug,
        'Error was ignored as specified in the ignoredErrors options.',
      );
      _options.recorder
          .recordLostEvent(DiscardReason.ignored, _getCategory(event));
      return _emptySentryId;
    }

    if (_options.containsIgnoredExceptionForType(event.throwable)) {
      _options.log(
        SentryLevel.debug,
        'Event was dropped as the exception ${event.throwable.runtimeType.toString()} is ignored.',
      );
      _options.recorder
          .recordLostEvent(DiscardReason.eventProcessor, _getCategory(event));
      return _emptySentryId;
    }

    if (_sampleRate() && event.type != 'feedback') {
      _options.recorder
          .recordLostEvent(DiscardReason.sampleRate, _getCategory(event));
      _options.log(
        SentryLevel.debug,
        'Event ${event.eventId.toString()} was dropped due to sampling decision.',
      );
      return _emptySentryId;
    }

    hint ??= Hint();

    SentryEvent? preparedEvent =
        _prepareEvent(event, hint, stackTrace: stackTrace);

    if (scope != null) {
      preparedEvent = await scope.applyToEvent(preparedEvent, hint);
    } else {
      _options.log(
          SentryLevel.debug, 'No scope to apply on event was provided');
    }

    // dropped by scope event processors
    if (preparedEvent == null) {
      return _emptySentryId;
    }

    preparedEvent = await runEventProcessors(
      preparedEvent,
      hint,
      _options.eventProcessors,
      _options,
    );

    // dropped by event processors
    if (preparedEvent == null) {
      return _emptySentryId;
    }

    preparedEvent = _createUserOrSetDefaultIpAddress(preparedEvent);

    preparedEvent = await _runBeforeSend(
      preparedEvent,
      hint,
    );

    // dropped by beforeSend
    if (preparedEvent == null) {
      return _emptySentryId;
    }

    // Event is fully processed and ready to be sent
    await _options.lifecycleRegistry
        .dispatchCallback(OnBeforeSendEvent(preparedEvent, hint));

    var attachments = List<SentryAttachment>.from(scope?.attachments ?? []);
    attachments.addAll(hint.attachments);
    var screenshot = hint.screenshot;
    if (screenshot != null) {
      attachments.add(screenshot);
    }

    var viewHierarchy = hint.viewHierarchy;
    if (viewHierarchy != null && event.type != 'feedback') {
      attachments.add(viewHierarchy);
    }

    var traceContext = scope?.span?.traceContext();
    if (traceContext == null) {
      if (scope != null) {
        scope.propagationContext.baggage ??=
            SentryBaggage({}, log: _options.log)
              ..setValuesFromScope(scope, _options);
        traceContext = SentryTraceContextHeader.fromBaggage(
            scope.propagationContext.baggage!);
      }
    } else {
      traceContext.replayId = scope?.replayId;
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

  bool _isIgnoredError(SentryEvent event) {
    if (event.message == null || _options.ignoreErrors.isEmpty) {
      return false;
    }

    var message = event.message!.formatted;
    return isMatchingRegexPattern(message, _options.ignoreErrors);
  }

  SentryEvent _prepareEvent(SentryEvent event, Hint hint,
      {dynamic stackTrace}) {
    event
      ..serverName = event.serverName ?? _options.serverName
      ..dist = event.dist ?? _options.dist
      ..environment = event.environment ?? _options.environment
      ..release = event.release ?? _options.release
      ..sdk = event.sdk ?? _options.sdk
      ..platform = event.platform ?? sdkPlatform(_options.platform.isWeb);

    if (event is SentryTransaction) {
      return event;
    }

    if (event.type == 'feedback') {
      return event;
    }

    if (event.exceptions?.isNotEmpty ?? false) {
      return event;
    }

    final isolateName = getIsolateName();
    // Isolates have no id, so the hashCode of the name will be used as id
    final isolateId = isolateName?.hashCode;

    if (event.throwableMechanism != null) {
      final extractedExceptionCauses = _exceptionFactory.extractor
          .flatten(event.throwableMechanism, stackTrace);

      SentryException? rootException;
      SentryException? currentException;
      final sentryThreads = <SentryThread>[];

      for (final extractedExceptionCause in extractedExceptionCauses) {
        var sentryException = _exceptionFactory.getSentryException(
          extractedExceptionCause.exception,
          stackTrace: extractedExceptionCause.stackTrace,
          removeSentryFrames: hint.get(TypeCheckHint.currentStackTrace),
        );
        if (extractedExceptionCause.source != null) {
          var mechanism =
              sentryException.mechanism ?? Mechanism(type: "generic");

          mechanism.source = extractedExceptionCause.source;
          sentryException.mechanism = mechanism;
        }

        SentryThread? sentryThread;

        if (!_options.platform.isWeb &&
            isolateName != null &&
            _options.attachThreads) {
          sentryException.threadId = isolateId;
          sentryThread = SentryThread(
            id: isolateId,
            name: isolateName,
            crashed: true,
            current: true,
          );
        }

        rootException ??= sentryException;
        currentException?.addException(sentryException);
        currentException = sentryException;

        if (sentryThread != null) {
          sentryThreads.add(sentryThread);
        }
      }

      final exceptions = [...?event.exceptions];
      if (rootException != null) {
        exceptions.add(rootException);
      }
      return event
        ..exceptions = exceptions
        ..threads = [
          ...?event.threads,
          ...sentryThreads,
        ];
    }

    // The stacktrace is not part of an exception,
    // therefore add it to the threads.
    // https://develop.sentry.dev/sdk/event-payloads/stacktrace/
    if (stackTrace != null || _options.attachStacktrace) {
      if (stackTrace == null || stackTrace == StackTrace.empty) {
        stackTrace = getCurrentStackTrace();
        hint.addAll({TypeCheckHint.currentStackTrace: true});
      }
      final sentryStackTrace = _stackTraceFactory.parse(
        stackTrace,
        removeSentryFrames: hint.get(TypeCheckHint.currentStackTrace),
      );
      if (sentryStackTrace.frames.isNotEmpty) {
        event.threads = [
          ...?event.threads,
          SentryThread(
            name: isolateName,
            id: isolateId,
            crashed: false,
            current: true,
            stacktrace: sentryStackTrace,
          ),
        ];
      }
    }

    return event;
  }

  SentryEvent _createUserOrSetDefaultIpAddress(SentryEvent event) {
    var user = event.user;
    final effectiveIpAddress =
        user?.ipAddress ?? (_options.sendDefaultPii ? _defaultIpAddress : null);

    if (effectiveIpAddress != null) {
      user ??= SentryUser(ipAddress: effectiveIpAddress);
      user.ipAddress = effectiveIpAddress;
      event.user = user;
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
    Hint? hint,
  }) async {
    hint ??= Hint();

    SentryTransaction? preparedTransaction =
        _prepareEvent(transaction, hint) as SentryTransaction;

    if (scope != null) {
      preparedTransaction = await scope.applyToEvent(preparedTransaction, hint)
          as SentryTransaction?;
    } else {
      _options.log(
          SentryLevel.debug, 'No scope to apply on transaction was provided');
    }

    // dropped by scope event processors
    if (preparedTransaction == null) {
      return _emptySentryId;
    }

    preparedTransaction = await runEventProcessors(
      preparedTransaction,
      hint,
      _options.eventProcessors,
      _options,
    ) as SentryTransaction?;

    // dropped by event processors
    if (preparedTransaction == null) {
      return _emptySentryId;
    }

    if (_isIgnoredTransaction(preparedTransaction)) {
      _options.log(
        SentryLevel.debug,
        'Transaction was ignored as specified in the ignoredTransactions options.',
      );

      _options.recorder.recordLostEvent(
          DiscardReason.ignored, _getCategory(preparedTransaction));
      return _emptySentryId;
    }

    preparedTransaction = _createUserOrSetDefaultIpAddress(preparedTransaction)
        as SentryTransaction;

    preparedTransaction =
        await _runBeforeSend(preparedTransaction, hint) as SentryTransaction?;

    // dropped by beforeSendTransaction
    if (preparedTransaction == null) {
      return _emptySentryId;
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

  bool _isIgnoredTransaction(SentryTransaction transaction) {
    if (_options.ignoreTransactions.isEmpty) {
      return false;
    }

    var name = transaction.tracer.name;
    return isMatchingRegexPattern(name, _options.ignoreTransactions);
  }

  /// Reports the [envelope] to Sentry.io.
  Future<SentryId?> captureEnvelope(SentryEnvelope envelope) {
    return _options.transport.send(envelope);
  }

  /// Reports the [feedback] to Sentry.io.
  Future<SentryId> captureFeedback(
    SentryFeedback feedback, {
    Scope? scope,
    Hint? hint,
  }) {
    // Cap feedback messages to max 4096 characters
    if (feedback.message.length > 4096) {
      feedback.message = feedback.message.substring(0, 4096);
    }
    final feedbackEvent = SentryEvent(
      type: 'feedback',
      contexts: Contexts(feedback: feedback),
      level: SentryLevel.info,
    );

    return captureEvent(
      feedbackEvent,
      scope: scope,
      hint: hint,
    );
  }

  @internal
  FutureOr<void> captureLog(
    SentryLog log, {
    Scope? scope,
  }) async {
    if (!_options.enableLogs) {
      return;
    }

    if (scope != null) {
      final merged = Map.of(scope.attributes)..addAll(log.attributes);
      log.attributes = merged;
    }

    log.attributes['sentry.sdk.name'] = SentryAttribute.string(
      _options.sdk.name,
    );
    log.attributes['sentry.sdk.version'] = SentryAttribute.string(
      _options.sdk.version,
    );
    final environment = _options.environment;
    if (environment != null) {
      log.attributes['sentry.environment'] = SentryAttribute.string(
        environment,
      );
    }
    final release = _options.release;
    if (release != null) {
      log.attributes['sentry.release'] = SentryAttribute.string(
        release,
      );
    }

    final propagationContext = scope?.propagationContext;
    if (propagationContext != null) {
      log.traceId = propagationContext.traceId;
    }
    final span = scope?.span;
    if (span != null) {
      log.attributes['sentry.trace.parent_span_id'] = SentryAttribute.string(
        span.context.spanId.toString(),
      );
    }

    final user = scope?.user;
    final id = user?.id;
    final email = user?.email;
    final name = user?.name;
    if (id != null) {
      log.attributes['user.id'] = SentryAttribute.string(id);
    }
    if (name != null) {
      log.attributes['user.name'] = SentryAttribute.string(name);
    }
    if (email != null) {
      log.attributes['user.email'] = SentryAttribute.string(email);
    }

    final beforeSendLog = _options.beforeSendLog;
    SentryLog? processedLog = log;
    if (beforeSendLog != null) {
      try {
        final callbackResult = beforeSendLog(log);

        if (callbackResult is Future<SentryLog?>) {
          processedLog = await callbackResult;
        } else {
          processedLog = callbackResult;
        }
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'The beforeSendLog callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }

    if (processedLog != null) {
      await _options.lifecycleRegistry
          .dispatchCallback(OnBeforeCaptureLog(processedLog));
      _options.logBatcher.addLog(processedLog);
    } else {
      _options.recorder.recordLostEvent(
        DiscardReason.beforeSend,
        DataCategory.logItem,
      );
    }
  }

  FutureOr<void> close() {
    final flush = _options.logBatcher.flush();
    if (flush is Future<void>) {
      return flush.then((_) => _options.httpClient.close());
    }
    _options.httpClient.close();
  }

  Future<SentryEvent?> _runBeforeSend(
    SentryEvent event,
    Hint hint,
  ) async {
    SentryEvent? processedEvent = event;
    final spanCountBeforeCallback =
        event is SentryTransaction ? event.spans.length : 0;

    final beforeSend = _options.beforeSend;
    final beforeSendTransaction = _options.beforeSendTransaction;
    final beforeSendFeedback = _options.beforeSendFeedback;
    String beforeSendName = 'beforeSend';

    try {
      if (event is SentryTransaction && beforeSendTransaction != null) {
        beforeSendName = 'beforeSendTransaction';
        final callbackResult = beforeSendTransaction(event, hint);
        if (callbackResult is Future<SentryTransaction?>) {
          processedEvent = await callbackResult;
        } else {
          processedEvent = callbackResult;
        }
      } else if (event.type == 'feedback' && beforeSendFeedback != null) {
        final callbackResult = beforeSendFeedback(event, hint);
        if (callbackResult is Future<SentryEvent?>) {
          processedEvent = await callbackResult;
        } else {
          processedEvent = callbackResult;
        }
      } else if (beforeSend != null) {
        final callbackResult = beforeSend(event, hint);
        if (callbackResult is Future<SentryEvent?>) {
          processedEvent = await callbackResult;
        } else {
          processedEvent = callbackResult;
        }
      }
    } catch (exception, stackTrace) {
      _options.log(
        SentryLevel.error,
        'The $beforeSendName callback threw an exception',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }

    final discardReason = DiscardReason.beforeSend;
    if (processedEvent == null) {
      _options.recorder.recordLostEvent(discardReason, _getCategory(event));
      if (event is SentryTransaction) {
        // We dropped the whole transaction, the dropped count includes all child spans + 1 root span
        _options.recorder.recordLostEvent(discardReason, DataCategory.span,
            count: spanCountBeforeCallback + 1);
      }
      _options.log(
        SentryLevel.debug,
        '${event.runtimeType} was dropped by $beforeSendName callback',
      );
    } else if (event is SentryTransaction &&
        processedEvent is SentryTransaction) {
      // If beforeSend removed only some spans we still report them as dropped
      final spanCountAfterCallback = processedEvent.spans.length;
      final droppedSpanCount = spanCountBeforeCallback - spanCountAfterCallback;
      if (droppedSpanCount > 0) {
        _options.recorder.recordLostEvent(discardReason, DataCategory.span,
            count: droppedSpanCount);
      }
    }

    return processedEvent;
  }

  bool _sampleRate() {
    if (_options.sampleRate != null && _random != null) {
      return (_options.sampleRate! < _random.nextDouble());
    }
    return false;
  }

  DataCategory _getCategory(SentryEvent event) {
    if (event is SentryTransaction) {
      return DataCategory.transaction;
    } else if (event.type == 'feedback') {
      return DataCategory.feedback;
    } else {
      return DataCategory.error;
    }
  }
}
