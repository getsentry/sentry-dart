import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'transport/data_category.dart';

import '../sentry.dart';
import 'client_reports/discard_reason.dart';
import 'sentry_tracer.dart';
import 'sentry_traces_sampler.dart';

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

  /// Captures the event.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureEvent' call is a no-op.",
      );
    } else {
      final item = _peek();
      final scope = await _cloneAndRunWithScope(item.scope, withScope);

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
        _options.logger(
          SentryLevel.error,
          'Error while capturing event with id: ${event.eventId}',
          exception: exception,
          stackTrace: stackTrace,
        );
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
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureException' call is a no-op.",
      );
    } else if (throwable == null) {
      _options.logger(
        SentryLevel.warning,
        'captureException called with null parameter.',
      );
    } else {
      final item = _peek();
      final scope = await _cloneAndRunWithScope(item.scope, withScope);

      try {
        var event = SentryEvent(
          throwable: throwable,
          timestamp: _options.clock(),
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
        _options.logger(
          SentryLevel.error,
          'Error while capturing exception',
          exception: exception,
          stackTrace: stackTrace,
        );
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
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureMessage' call is a no-op.",
      );
    } else if (message == null) {
      _options.logger(
        SentryLevel.warning,
        'captureMessage called with null parameter.',
      );
    } else {
      final item = _peek();
      final scope = await _cloneAndRunWithScope(item.scope, withScope);

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
        _options.logger(
          SentryLevel.error,
          'Error while capturing message with id: $message',
          exception: exception,
          stackTrace: stackTrace,
        );
      } finally {
        _lastEventId = sentryId;
      }
    }
    return sentryId;
  }

  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) async {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureUserFeedback' call is a no-op.",
      );
      return;
    }
    if (userFeedback.eventId == SentryId.empty()) {
      _options.logger(
        SentryLevel.warning,
        'Captured UserFeedback with empty id, dropping the feedback',
      );
      return;
    }
    try {
      final item = _peek();

      await item.client.captureUserFeedback(userFeedback);
    } catch (exception, stacktrace) {
      _options.logger(
        SentryLevel.error,
        'Error while capturing user feedback for ${userFeedback.eventId}',
        exception: exception,
        stackTrace: stacktrace,
      );
    }
  }

  Future<Scope> _cloneAndRunWithScope(
      Scope scope, ScopeCallback? withScope) async {
    if (withScope != null) {
      try {
        scope = scope.clone();
        await withScope(scope);
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'Exception in withScope callback.',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
    }
    return scope;
  }

  /// Adds a breacrumb to the current Scope
  Future<void> addBreadcrumb(Breadcrumb crumb, {dynamic hint}) async {
    if (!_isEnabled) {
      _options.logger(
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
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'bindClient' call is a no-op.",
      );
    } else {
      final item = _peek();
      _options.logger(SentryLevel.debug, 'New client bound to scope.');
      item.client = client;
    }
  }

  /// Clones the Hub
  Hub clone() {
    if (!_isEnabled) {
      _options.logger(SentryLevel.warning, 'Disabled Hub cloned.');
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
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'close' call is a no-op.",
      );
    } else {
      // close integrations
      for (final integration in _options.integrations) {
        await integration.close();
      }

      final item = _peek();

      try {
        item.client.close();
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'Error while closing the Hub',
          exception: exception,
          stackTrace: stackTrace,
        );
      }

      _isEnabled = false;
    }
  }

  /// Configures the scope through the callback.
  FutureOr<void> configureScope(ScopeCallback callback) async {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'configureScope' call is a no-op.",
      );
    } else {
      final item = _peek();

      try {
        await callback(item.scope);
      } catch (err) {
        _options.logger(
          SentryLevel.error,
          "Error in the 'configureScope' callback, error: $err",
        );
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
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'startTransaction' call is a no-op.",
      );
    } else if (!_options.isTracingEnabled()) {
      _options.logger(
        SentryLevel.info,
        "Tracing is disabled and this 'startTransaction' returns a no-op.",
      );
    } else {
      final item = _peek();

      final samplingContext = SentrySamplingContext(
          transactionContext, customSamplingContext ?? {});

      // if transactionContext has no sampled decision, run the traces sampler
      if (transactionContext.samplingDecision == null) {
        final samplingDecision = _tracesSampler.sample(samplingContext);
        transactionContext =
            transactionContext.copyWith(samplingDecision: samplingDecision);
      }

      final tracer = SentryTracer(
        transactionContext,
        this,
        startTimestamp: startTimestamp,
        waitForChildren: waitForChildren ?? false,
        autoFinishAfter: autoFinishAfter,
        trimEnd: trimEnd ?? false,
        onFinish: onFinish,
      );
      if (bindToScope ?? false) {
        item.scope.span = tracer;
      }

      return tracer;
    }

    return NoOpSentrySpan();
  }

  /// Gets the current active transaction or span.
  ISentrySpan? getSpan() {
    ISentrySpan? span;
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'getSpan' call is a no-op.",
      );
    } else if (!_options.isTracingEnabled()) {
      _options.logger(
        SentryLevel.info,
        "Tracing is disabled and this 'getSpan' returns null.",
      );
    } else {
      final item = _peek();

      span = item.scope.span;
    }

    return span;
  }

  @internal
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    SentryTraceContextHeader? traceContext,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureTransaction' call is a no-op.",
      );
    } else if (!_options.isTracingEnabled()) {
      _options.logger(
        SentryLevel.info,
        "Tracing is disabled and this 'captureTransaction' call is a no-op.",
      );
    } else if (!transaction.finished) {
      _options.logger(
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
        _options.logger(
          SentryLevel.warning,
          'Transaction ${transaction.eventId} was dropped due to sampling decision.',
        );
      } else {
        try {
          sentryId = await item.client.captureTransaction(
            transaction,
            scope: item.scope,
            traceContext: traceContext,
          );
        } catch (exception, stackTrace) {
          _options.logger(
            SentryLevel.error,
            'Error while capturing transaction with id: ${transaction.eventId}',
            exception: exception,
            stackTrace: stackTrace,
          );
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
        if (event.transaction == null) {
          event = event.copyWith(transaction: pair.value);
        }
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

  _WeakMap(this._options);

  void add(
    dynamic throwable,
    ISentrySpan span,
    String transaction,
  ) {
    if (throwable == null) {
      return;
    }
    try {
      if (_expando[throwable] == null) {
        _expando[throwable] = MapEntry(span, transaction);
      }
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.info,
        'Throwable type: ${throwable.runtimeType} is not supported for associating errors to a transaction.',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }

  MapEntry<ISentrySpan, String>? get(dynamic throwable) {
    if (throwable == null) {
      return null;
    }
    try {
      return _expando[throwable] as MapEntry<ISentrySpan, String>?;
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.info,
        'Throwable type: ${throwable.runtimeType} is not supported for associating errors to a transaction.',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
    return null;
  }
}
