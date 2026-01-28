import 'dart:collection';

import 'package:meta/meta.dart';

import '../../hub.dart';
import '../../hub_adapter.dart';
import '../../protocol.dart';
import 'instrumentation_span.dart';
import 'span_factory.dart';

/// Helper for instrumenting operations with transaction stack support.
/// Used for nested database transactions (e.g., Drift).
@internal
class TransactionInstrumentation {
  final Hub _hub;
  final String _origin;
  final String _loggerName;
  final InstrumentationSpanFactory _factory;

  final ListQueue<InstrumentationSpan?> _transactionStack = ListQueue();

  @visibleForTesting
  ListQueue<InstrumentationSpan?> get transactionStack => _transactionStack;

  TransactionInstrumentation(
    Hub? hub,
    this._origin,
    this._loggerName, {
    InstrumentationSpanFactory? factory,
  })  : _hub = hub ?? HubAdapter(),
        _factory = factory ?? LegacyInstrumentationSpanFactory();

  InstrumentationSpan? _getParent() {
    return _transactionStack.lastOrNull ?? _factory.getSpan(_hub);
  }

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
      _transactionStack.add(newParent);
      return result;
    } catch (exception) {
      newParent.throwable = exception;
      newParent.status = SpanStatus.internalError();
      rethrow;
    }
  }

  /// Finishes the current transaction span and pops it from the stack.
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
