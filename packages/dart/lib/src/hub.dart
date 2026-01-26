import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';

import '../sentry.dart';
import 'client_reports/discard_reason.dart';
import 'profiling.dart';
import 'sentry_tracer.dart';
import 'sentry_traces_sampler.dart';
import 'transport/data_category.dart';

/// Configures the scope through the callback.
typedef ScopeCallback = FutureOr<void> Function(Scope);

/// Called when a transaction is finished.
typedef OnTransactionFinish = FutureOr<void> Function(ISentrySpan transaction);

/// SDK API contract which combines a client and scope management
class Hub {
  static SentryClient _getClient(SentryOptions options) {
    return SentryClient(options);
  }

  final ListQueue<_StackItem> _stack = ListQueue();

  // peek can never return null since Stack can be created only with an item and
  // pop does not drop the last item.
  _StackItem _peek() => _stack.first;

  final SentryOptions _options;

  @internal
  SentryOptions get options => _options;

  late SentryTracesSampler _tracesSampler;

  late final _WeakMap _throwableToSpan;

  factory Hub(SentryOptions options) {
    _validateOptions(options);

    return Hub._(options);
  }

  Hub._(this._options) {
    _tracesSampler = SentryTracesSampler(_options);
    _stack.add(_StackItem(_getClient(_options), Scope(_options)));
    _isEnabled = true;
    _throwableToSpan = _WeakMap(_options);
  }

  static void _validateOptions(SentryOptions options) {
    if (options.dsn == null) {
      throw ArgumentError('DSN is required.');
    }
  }

  bool _isEnabled = false;

  /// Check if the Hub is enabled/active.
  bool get isEnabled => _isEnabled;

  SentryId _lastEventId = SentryId.empty();

  /// Last event id recorded by the Hub
  SentryId get lastEventId => _lastEventId;

  @internal
  Scope get scope => _peek().scope;

  /// Captures the event.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Hint? hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'captureEvent' call is a no-op.",
      );
    } else {
      final item = _peek();
      late Scope scope;
      final s = _cloneAndRunWithScope(item.scope, withScope);
      if (s is Future<Scope>) {
        scope = await s;
      } else {
        scope = s;
      }

      try {
        if (_options.isTracingEnabled()) {
          event = _assignTraceContext(event);
        }

        sentryId = await item.client.captureEvent(
          event,
          stackTrace: stackTrace,
          scope: scope,
          hint: hint,
        );
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'Error while capturing event with id: ${event.eventId}',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      } finally {
        _lastEventId = sentryId;
      }
    }
    return sentryId;
  }

  /// Captures the exception
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Hint? hint,
    SentryMessage? message,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'captureException' call is a no-op.",
      );
    } else if (throwable == null) {
      _options.log(
        SentryLevel.warning,
        'captureException called with null parameter.',
      );
    } else {
      final item = _peek();
      late Scope scope;
      final s = _cloneAndRunWithScope(item.scope, withScope);
      if (s is Future<Scope>) {
        scope = await s;
      } else {
        scope = s;
      }

      try {
        var event = SentryEvent(
          throwable: throwable,
          timestamp: _options.clock(),
          message: message,
        );

        if (_options.isTracingEnabled()) {
          event = _assignTraceContext(event);
        }

        sentryId = await item.client.captureEvent(
          event,
          stackTrace: stackTrace,
          scope: scope,
          hint: hint,
        );
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'Error while capturing exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      } finally {
        _lastEventId = sentryId;
      }
    }

    return sentryId;
  }

  /// Captures the message.
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List<dynamic>? params,
    Hint? hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'captureMessage' call is a no-op.",
      );
    } else if (message == null) {
      _options.log(
        SentryLevel.warning,
        'captureMessage called with null parameter.',
      );
    } else {
      final item = _peek();
      late Scope scope;
      final s = _cloneAndRunWithScope(item.scope, withScope);
      if (s is Future<Scope>) {
        scope = await s;
      } else {
        scope = s;
      }

      try {
        sentryId = await item.client.captureMessage(
          message,
          level: level,
          template: template,
          params: params,
          scope: scope,
          hint: hint,
        );
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'Error while capturing message with id: $message',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      } finally {
        _lastEventId = sentryId;
      }
    }
    return sentryId;
  }

  /// Captures the feedback.
  Future<SentryId> captureFeedback(
    SentryFeedback feedback, {
    Hint? hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'captureFeedback' call is a no-op.",
      );
    } else {
      final item = _peek();
      late Scope scope;
      final s = _cloneAndRunWithScope(item.scope, withScope);
      if (s is Future<Scope>) {
        scope = await s;
      } else {
        scope = s;
      }

      try {
        sentryId = await item.client.captureFeedback(
          feedback,
          hint: hint,
          scope: scope,
        );
      } catch (exception, stacktrace) {
        _options.log(
          SentryLevel.error,
          'Error while capturing feedback',
          exception: exception,
          stackTrace: stacktrace,
        );
      }
    }
    return sentryId;
  }

  FutureOr<void> captureLog(SentryLog log) async {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'captureLog' call is a no-op.",
      );
    } else {
      final item = _peek();
      late Scope scope;
      final s = _cloneAndRunWithScope(item.scope, null);
      if (s is Future<Scope>) {
        scope = await s;
      } else {
        scope = s;
      }

      try {
        await item.client.captureLog(
          log,
          scope: scope,
        );
      } catch (exception, stacktrace) {
        _options.log(
          SentryLevel.error,
          'Error while capturing log',
          exception: exception,
          stackTrace: stacktrace,
        );
      }
    }
  }

  Future<void> captureMetric(SentryMetric metric) async {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'captureMetric' call is a no-op.",
      );
    } else {
      final item = _peek();
      late Scope scope;
      final s = _cloneAndRunWithScope(item.scope, null);
      if (s is Future<Scope>) {
        scope = await s;
      } else {
        scope = s;
      }

      try {
        await item.client.captureMetric(
          metric,
          scope: scope,
        );
      } catch (exception, stacktrace) {
        _options.log(
          SentryLevel.error,
          'Error while capturing metric',
          exception: exception,
          stackTrace: stacktrace,
        );
      }
    }
  }

  FutureOr<Scope> _cloneAndRunWithScope(
      Scope scope, ScopeCallback? withScope) async {
    if (withScope != null) {
      try {
        scope = scope.clone();
        final s = withScope(scope);
        if (s is Future) {
          await s;
        }
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'Exception in withScope callback.',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }
    return scope;
  }

  void setAttributes(Map<String, SentryAttribute> attributes) {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'setAttributes' call is a no-op.",
      );
    } else {
      final item = _peek();
      item.scope.setAttributes(attributes);
    }
  }

  void removeAttribute(String key) {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'removeAttribute' call is a no-op.",
      );
    } else {
      final item = _peek();
      item.scope.removeAttribute(key);
    }
  }

  /// Adds a breadcrumb to the current Scope
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'addBreadcrumb' call is a no-op.",
      );
    } else {
      final item = _peek();
      await item.scope.addBreadcrumb(crumb, hint: hint);
    }
  }

  /// Binds a different client to the hub
  void bindClient(SentryClient client) {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'bindClient' call is a no-op.",
      );
    } else {
      final item = _peek();
      _options.log(SentryLevel.debug, 'New client bound to scope.');
      item.client = client;
    }
  }

  /// Clones the Hub
  Hub clone() {
    if (!_isEnabled) {
      _options.log(SentryLevel.warning, 'Disabled Hub cloned.');
    }
    final clone = Hub(_options);
    for (final item in _stack) {
      clone._stack.add(_StackItem(item.client, item.scope.clone()));
    }
    return clone;
  }

  /// Flushes out the queue for up to timeout seconds and disable the Hub.
  Future<void> close() async {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'close' call is a no-op.",
      );
    } else {
      // close integrations
      for (final integration in _options.integrations) {
        final close = integration.close();
        if (close is Future) {
          await close;
        }
      }

      final item = _peek();

      try {
        final close = item.client.close();
        if (close is Future<void>) {
          await close;
        }
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'Error while closing the Hub',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }

      _isEnabled = false;
    }
  }

  /// Configures the scope through the callback.
  FutureOr<void> configureScope(ScopeCallback callback) async {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'configureScope' call is a no-op.",
      );
    } else {
      final item = _peek();

      try {
        final result = callback(item.scope);
        if (result is Future) {
          await result;
        }
      } catch (err) {
        _options.log(
          SentryLevel.error,
          "Error in the 'configureScope' callback, error: $err",
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }
  }

  /// Creates a Transaction and returns the instance.
  ISentrySpan startTransaction(
    String name,
    String operation, {
    String? description,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    OnTransactionFinish? onFinish,
    Map<String, dynamic>? customSamplingContext,
  }) =>
      startTransactionWithContext(
        SentryTransactionContext(
          name,
          operation,
          description: description,
          origin: SentryTraceOrigins.manual,
        ),
        startTimestamp: startTimestamp,
        bindToScope: bindToScope,
        waitForChildren: waitForChildren,
        autoFinishAfter: autoFinishAfter,
        trimEnd: trimEnd,
        onFinish: onFinish,
        customSamplingContext: customSamplingContext,
      );

  /// Creates a Transaction and returns the instance.
  ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    OnTransactionFinish? onFinish,
  }) {
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'startTransaction' call is a no-op.",
      );
    } else if (_options.isTracingEnabled()) {
      final item = _peek();

      // if transactionContext has no sampling decision yet, run the traces sampler
      var samplingDecision = transactionContext.samplingDecision;
      final propagationContext = scope.propagationContext;
      // Store the generated/used sampleRand on the propagation context so
      // that subsequent transactions in the same trace reuse it.
      propagationContext.sampleRand ??= Random().nextDouble();

      if (samplingDecision == null) {
        final samplingContext = SentrySamplingContext(
            transactionContext, customSamplingContext ?? {});

        samplingDecision = _tracesSampler.sample(
          samplingContext,
          // sampleRand is guaranteed not to be null here
          propagationContext.sampleRand!,
        );

        // Persist the sampling decision within the transaction context
        transactionContext.samplingDecision = samplingDecision;
      }

      transactionContext.origin ??= SentryTraceOrigins.manual;
      transactionContext.traceId = propagationContext.traceId;

      // Persist the "sampled" decision onto the propagation context the
      // first time we obtain one for the current trace.
      // Subsequent transactions do not affect the sampled flag.
      propagationContext.applySamplingDecision(samplingDecision.sampled);

      SentryProfiler? profiler;
      if (_profilerFactory != null &&
          _tracesSampler.sampleProfiling(samplingDecision)) {
        profiler = _profilerFactory?.startProfiler(transactionContext);
      }

      final tracer = SentryTracer(
        transactionContext,
        this,
        startTimestamp: startTimestamp,
        waitForChildren: waitForChildren ?? false,
        autoFinishAfter: autoFinishAfter,
        trimEnd: trimEnd ?? false,
        onFinish: onFinish,
        profiler: profiler,
      );
      if (bindToScope ?? false) {
        item.scope.span = tracer;
      }

      return tracer;
    }

    return NoOpSentrySpan();
  }

  @internal
  void generateNewTrace() {
    // Create a brand-new trace and reset the sampling flag and sampleRand so
    // that the next root transaction can set it again.
    scope.propagationContext.resetTrace();
  }

  /// Gets the current active transaction or span.
  ISentrySpan? getSpan() {
    ISentrySpan? span;
    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'getSpan' call is a no-op.",
      );
    } else if (_options.isTracingEnabled()) {
      final item = _peek();

      span = item.scope.span;
    }

    return span;
  }

  @internal
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    SentryTraceContextHeader? traceContext,
    Hint? hint,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.log(
        SentryLevel.warning,
        "Instance is disabled and this 'captureTransaction' call is a no-op.",
      );
    } else if (!_options.isTracingEnabled()) {
      _options.log(
        SentryLevel.info,
        "Tracing is disabled and this 'captureTransaction' call is a no-op.",
      );
    } else if (!transaction.finished) {
      _options.log(
        SentryLevel.warning,
        'Capturing unfinished transaction: ${transaction.eventId}',
      );
    } else {
      final item = _peek();

      if (!transaction.sampled) {
        _options.recorder.recordLostEvent(
          DiscardReason.sampleRate,
          DataCategory.transaction,
        );
        _options.recorder.recordLostEvent(
          DiscardReason.sampleRate,
          DataCategory.span,
          count: transaction.spans.length + 1,
        );
        _options.log(
          SentryLevel.warning,
          'Transaction ${transaction.eventId} was dropped due to sampling decision.',
        );
      } else {
        try {
          sentryId = await item.client.captureTransaction(
            transaction,
            scope: item.scope,
            traceContext: traceContext,
            hint: hint,
          );
        } catch (exception, stackTrace) {
          _options.log(
            SentryLevel.error,
            'Error while capturing transaction with id: ${transaction.eventId}',
            exception: exception,
            stackTrace: stackTrace,
          );
          if (_options.automatedTestMode) {
            rethrow;
          }
        }
      }
    }
    return sentryId;
  }

  @internal
  void setSpanContext(
    dynamic throwable,
    ISentrySpan span,
    String transaction,
  ) =>
      _throwableToSpan.add(throwable, span, transaction);

  @internal
  SentryProfilerFactory? get profilerFactory => _profilerFactory;

  @internal
  set profilerFactory(SentryProfilerFactory? value) => _profilerFactory = value;

  SentryProfilerFactory? _profilerFactory;

  SentryEvent _assignTraceContext(SentryEvent event) {
    // assign trace context
    if (event.throwable != null && event.contexts.trace == null) {
      // set span to event.contexts.trace
      final pair = _throwableToSpan.get(event.throwable);
      if (pair != null) {
        final span = pair.key;
        final spanContext = span.context;
        event.contexts.trace = spanContext.toTraceContext(
          sampled: span.samplingDecision?.sampled,
        );

        // set transaction name to event.transaction
        event.transaction ??= pair.value;
      }
    }
    return event;
  }
}

class _StackItem {
  SentryClient client;

  final Scope scope;

  _StackItem(this.client, this.scope);
}

class _WeakMap {
  final _expando = Expando();

  final SentryOptions _options;

  final throwableHandler = UnsupportedThrowablesHandler();

  _WeakMap(this._options);

  void add(
    dynamic throwable,
    ISentrySpan span,
    String transaction,
  ) {
    if (throwable == null) {
      return;
    }
    throwable = throwableHandler.wrapIfUnsupportedType(throwable);
    try {
      if (_expando[throwable] == null) {
        _expando[throwable] = MapEntry(span, transaction);
      }
    } catch (exception, stackTrace) {
      _options.log(
        SentryLevel.info,
        'Throwable type: ${throwable.runtimeType} is not supported for associating errors to a transaction.',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
  }

  MapEntry<ISentrySpan, String>? get(dynamic throwable) {
    if (throwable == null) {
      return null;
    }
    throwable = throwableHandler.wrapIfUnsupportedType(throwable);
    try {
      return _expando[throwable] as MapEntry<ISentrySpan, String>?;
    } catch (exception, stackTrace) {
      _options.log(
        SentryLevel.info,
        'Throwable type: ${throwable.runtimeType} is not supported for associating errors to a transaction.',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
    return null;
  }
}

/// A handler for unsupported throwables used for Expando<Object>.
@visibleForTesting
class UnsupportedThrowablesHandler {
  final _unsupportedTypes = {String, int, double, bool};
  final _unsupportedThrowables = <Object>{};

  dynamic wrapIfUnsupportedType(dynamic throwable) {
    if (_unsupportedTypes.contains(throwable.runtimeType)) {
      throwable = _UnsupportedExceptionWrapper(Exception(throwable));
      _unsupportedThrowables.add(throwable);
    }
    return _unsupportedThrowables.lookup(throwable) ?? throwable;
  }
}

class _UnsupportedExceptionWrapper {
  _UnsupportedExceptionWrapper(this.exception);

  final Exception exception;

  @override
  bool operator ==(Object other) {
    if (other is _UnsupportedExceptionWrapper) {
      return other.exception.toString() == exception.toString();
    }
    return false;
  }

  @override
  int get hashCode => exception.toString().hashCode;
}
