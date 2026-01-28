// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart';

@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  late final InstrumentationSpanFactory _factory;

  /// Represents a stack of Drift transaction spans.
  /// These are used to allow nested spans if the user nests Drift transactions.
  /// If the transaction stack is empty, the spans are attached to the
  /// active span in the Hub's scope.
  final ListQueue<InstrumentationSpan> _transactionStack = ListQueue();

  @visibleForTesting
  ListQueue<InstrumentationSpan> get transactionStack => _transactionStack;

  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter() {
    _factory = _hub.options.spanFactory;
  }

  /// Gets the parent span for operations.
  /// Returns the last transaction on the stack, or falls back to the current
  /// span from the hub's scope if the stack is empty.
  InstrumentationSpan? _getParent() {
    return _transactionStack.lastOrNull ?? _factory.getSpan(_hub);
  }

  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
    String? operation,
  }) async {
    final parentSpan = _getParent();
    if (parentSpan == null) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not start span for the Drift operation: $description',
        logger: loggerName,
      );
      return execute();
    }

    final span = _factory.createSpan(
      parentSpan,
      operation ?? SentrySpanOperations.dbSqlQuery,
      description: description,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;

    span.setData(
      SentrySpanData.dbSystemKey,
      SentrySpanData.dbSystemSqlite,
    );

    if (dbName != null) {
      span.setData(SentrySpanData.dbNameKey, dbName);
    }

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

  T beginTransaction<T>(
    T Function() execute, {
    String? dbName,
  }) {
    final parentSpan = _getParent();
    if (parentSpan == null) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not start span for Drift operation: Begin Transaction',
        logger: loggerName,
      );
      return execute();
    }

    final newParent = _factory.createSpan(
      parentSpan,
      SentrySpanOperations.dbSqlTransaction,
      description: SentrySpanDescriptions.dbTransaction,
    );

    // If span creation failed (e.g., hit span limit), just execute without
    // affecting the stack. Operations inside can still attach to whatever
    // active span exists via _getParent() fallback.
    if (newParent == null) {
      return execute();
    }

    newParent.origin = _origin;

    newParent.setData(
      SentrySpanData.dbSystemKey,
      SentrySpanData.dbSystemSqlite,
    );

    if (dbName != null) {
      newParent.setData(SentrySpanData.dbNameKey, dbName);
    }

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

  Future<T> finishTransaction<T>(Future<T> Function() execute) async {
    if (_transactionStack.isEmpty) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not finish span for Drift operation: Finish Transaction',
        logger: loggerName,
      );
      return execute();
    }

    final parentSpan = _transactionStack.last;

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

  Future<T> abortTransaction<T>(Future<T> Function() execute) async {
    if (_transactionStack.isEmpty) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not finish span for Drift operation: Abort Transaction',
        logger: loggerName,
      );
      return execute();
    }

    final parentSpan = _transactionStack.last;

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
