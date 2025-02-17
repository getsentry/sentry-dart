// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;

  /// Represents a stack of Drift transaction spans.
  /// These are used to allow nested spans if the user nests Drift transactions.
  /// If the transaction stack is empty, the spans are attached to the
  /// active span in the Hub's scope.
  final ListQueue<ISentrySpan?> _transactionStack = ListQueue();

  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter();

  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
    String? operation,
  }) async {
    final parentSpan = _transactionStack.lastOrNull ?? _hub.getSpan();
    if (parentSpan == null) {
      _hub.options.logger(SentryLevel.info, 'Drift: active Sentry transaction does not exist, could not start span for the Drift operation: $description');
      return execute();
    }

    final span = parentSpan?.startChild(
      operation ?? SentrySpanOperations.dbSqlQuery,
      description: description,
    );

    span?.origin = _origin;

    span?.setData(
      SentrySpanData.dbSystemKey,
      SentrySpanData.dbSystemSqlite,
    );

    if (dbName != null) {
      span?.setData(SentrySpanData.dbNameKey, dbName);
    }

    try {
      final result = await execute();
      span?.status = SpanStatus.ok();

      return result;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await span?.finish();
    }
  }

  T beginTransaction<T>(
    T Function() execute, {
    String? dbName,
  }) {
    final parentSpan = _transactionStack.lastOrNull ?? _hub.getSpan();
    if (parentSpan == null) {
      _hub.options.logger(SentryLevel.info, 'Drift: active Sentry transaction does not exist, could not start span for Drift operation: Begin Transaction');
      return execute();
    }

    final newParent = parentSpan.startChild(
          SentrySpanOperations.dbSqlTransaction,
          description: SentrySpanDescriptions.dbTransaction,
        ) ??
        _hub.getSpan()?.startChild(
              SentrySpanOperations.dbSqlTransaction,
              description: SentrySpanDescriptions.dbTransaction,
            );

    _transactionStack.add(newParent);

    newParent?.origin = _origin;

    newParent?.setData(
      SentrySpanData.dbSystemKey,
      SentrySpanData.dbSystemSqlite,
    );

    if (dbName != null) {
      newParent?.setData(SentrySpanData.dbNameKey, dbName);
    }

    try {
      final result = execute();
      newParent?.status = SpanStatus.unknown();

      return result;
    } catch (exception) {
      newParent?.throwable = exception;
      newParent?.status = SpanStatus.internalError();

      rethrow;
    }
  }

  Future<T> finishTransaction<T>(Future<T> Function() execute) async {
    final parentSpan = _transactionStack.removeLast();
    if (parentSpan == null) {
      _hub.options.logger(SentryLevel.info, 'Drift: active Sentry transaction does not exist, could not finish span for Drift operation: Finish Transaction');
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
    }
  }

  Future<T> abortTransaction<T>(Future<T> Function() execute) async {
    final parentSpan = _transactionStack.removeLast();
    if (parentSpan == null) {
      _hub.options.logger(SentryLevel.info, 'Drift: active Sentry transaction does not exist, could not finish span for Drift operation: Abort Transaction');
      return Future<T>.value();
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
    }
  }
}
