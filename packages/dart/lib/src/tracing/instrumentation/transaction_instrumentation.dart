import 'dart:collection';

import 'package:meta/meta.dart';

import '../../hub.dart';
import '../../hub_adapter.dart';
import '../../protocol.dart';
import 'instrumentation_span.dart';
import 'span_factory.dart';

/// Helper class for instrumenting operations with transaction stack support.
///
/// This class extends the functionality of [SentryInstrumentation] by maintaining
/// a stack of transaction spans, enabling proper parent-child relationships for
/// nested database transactions (e.g., Drift).
///
/// When operations are wrapped, the parent span is determined by:
/// 1. The last transaction on the stack (if any)
/// 2. Otherwise, the current span from the hub's scope
///
/// Example usage:
/// ```dart
/// final instrumentation = TransactionInstrumentation(hub, 'auto.db.drift', 'sentry_drift');
///
/// // Begin a transaction - pushes to stack
/// instrumentation.beginTransaction(
///   operation: 'db.sql.transaction',
///   description: 'Transaction',
///   data: {'db.system': 'sqlite'},
///   execute: () => executor.beginTransaction(),
/// );
///
/// // Operations inside transaction use the transaction span as parent
/// await instrumentation.asyncWrapInSpan(
///   operation: 'db.sql.query',
///   description: 'SELECT * FROM users',
///   execute: () => executor.runSelect(...),
/// );
///
/// // Finish transaction - pops from stack
/// await instrumentation.finishTransaction(execute: () => executor.send());
/// ```
@internal
class TransactionInstrumentation {
  final Hub _hub;
  final String _origin;
  final String _loggerName;
  final InstrumentationSpanFactory _factory;

  /// Stack of transaction spans for nested transaction support.
  final ListQueue<InstrumentationSpan?> _transactionStack = ListQueue();

  /// Exposes the transaction stack for testing purposes.
  @visibleForTesting
  ListQueue<InstrumentationSpan?> get transactionStack => _transactionStack;

  /// Creates a new [TransactionInstrumentation] instance.
  ///
  /// [hub] - The Sentry hub to use for span operations.
  /// [origin] - The origin identifier for spans (e.g., 'auto.db.drift').
  /// [loggerName] - The logger name for warning messages (e.g., 'sentry_drift').
  /// [factory] - Optional custom span factory. Defaults to [LegacyInstrumentationSpanFactory].
  TransactionInstrumentation(
    Hub? hub,
    this._origin,
    this._loggerName, {
    InstrumentationSpanFactory? factory,
  })  : _hub = hub ?? HubAdapter(),
        _factory = factory ?? LegacyInstrumentationSpanFactory();

  /// Gets the parent span for operations.
  ///
  /// Returns the last transaction on the stack, or falls back to the current
  /// span from the hub's scope if the stack is empty.
  InstrumentationSpan? _getParent() {
    return _transactionStack.lastOrNull ?? _factory.getCurrentSpan(_hub);
  }

  /// Wraps an async operation in a span.
  ///
  /// Parent is resolved from the transaction stack or hub scope.
  /// If no parent is available, logs a warning and executes without tracing.
  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? operation,
    Map<String, dynamic>? data,
  }) async {
    final parentSpan = _getParent();
    if (parentSpan == null) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not start span for operation: $description',
        logger: _loggerName,
      );
      return execute();
    }

    final span = _factory.createChildSpan(
      parentSpan,
      operation ?? 'db.sql.query',
      description: description,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    data?.forEach((key, value) => span.setData(key, value));

    try {
      final result = await execute();
      span.status = SpanStatus.ok();
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span.finish();
    }
  }

  /// Begins a transaction span and pushes it to the stack.
  ///
  /// The transaction span becomes the parent for subsequent operations
  /// until [finishTransaction] or [abortTransaction] is called.
  ///
  /// If no parent is available, logs a warning and executes without tracing.
  /// On success, sets status to [SpanStatus.unknown] and pushes to stack.
  /// On error, sets status to [SpanStatus.internalError] and does NOT push to stack.
  T beginTransaction<T>(
    T Function() execute, {
    required String operation,
    required String description,
    Map<String, dynamic>? data,
  }) {
    final parentSpan = _getParent();
    if (parentSpan == null) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not start span for: Begin Transaction',
        logger: _loggerName,
      );
      return execute();
    }

    final newParent = _factory.createChildSpan(
      parentSpan,
      operation,
      description: description,
    );

    if (newParent == null) {
      return execute();
    }

    newParent.origin = _origin;
    data?.forEach((key, value) => newParent.setData(key, value));

    try {
      final result = execute();
      newParent.status = SpanStatus.unknown();

      // Only add to the stack if no error occurred
      _transactionStack.add(newParent);

      return result;
    } catch (exception) {
      newParent.throwable = exception;
      newParent.status = SpanStatus.internalError();
      rethrow;
    }
  }

  /// Finishes the current transaction span and pops it from the stack.
  ///
  /// On success, sets status to [SpanStatus.ok].
  /// On error, sets status to [SpanStatus.internalError].
  /// The span is always finished and popped from the stack.
  Future<T> finishTransaction<T>(Future<T> Function() execute) async {
    final parentSpan = _transactionStack.lastOrNull;
    if (parentSpan == null) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not finish span for: Finish Transaction',
        logger: _loggerName,
      );
      return execute();
    }

    try {
      final result = await execute();
      parentSpan.status = SpanStatus.ok();
      return result;
    } catch (exception) {
      parentSpan.throwable = exception;
      parentSpan.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await parentSpan.finish();
      _transactionStack.removeLast();
    }
  }

  /// Aborts the current transaction span and pops it from the stack.
  ///
  /// On success, sets status to [SpanStatus.aborted].
  /// On error, sets status to [SpanStatus.internalError].
  /// The span is always finished and popped from the stack.
  Future<T> abortTransaction<T>(Future<T> Function() execute) async {
    final parentSpan = _transactionStack.lastOrNull;
    if (parentSpan == null) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not finish span for: Abort Transaction',
        logger: _loggerName,
      );
      return execute();
    }

    try {
      final result = await execute();
      parentSpan.status = SpanStatus.aborted();
      return result;
    } catch (exception) {
      parentSpan.throwable = exception;
      parentSpan.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await parentSpan.finish();
      _transactionStack.removeLast();
    }
  }
}
