// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  final ListQueue<ISentrySpan?> _spanStack = ListQueue();

  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter() {
    _spanStack.add(hub?.getSpan());
  }

  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
    String? operation,
  }) async {
    final parentSpan = _spanStack.last;
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
    final parentSpan = _spanStack.last;
    final newParent = parentSpan?.startChild(
          SentrySpanOperations.dbSqlTransaction,
          description: SentrySpanDescriptions.dbTransaction,
        ) ??
        _hub.getSpan()?.startChild(
              SentrySpanOperations.dbSqlTransaction,
              description: SentrySpanDescriptions.dbTransaction,
            );

    _spanStack.add(newParent);

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
    final parentSpan = _spanStack.removeLast();

    try {
      final result = await execute();
      parentSpan?.status = SpanStatus.ok();

      return result;
    } catch (exception) {
      parentSpan?.throwable = exception;
      parentSpan?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await parentSpan?.finish();
    }
  }

  Future<T> abortTransaction<T>(Future<T> Function() execute) async {
    final parentSpan = _spanStack.removeLast();

    try {
      final result = await execute();
      parentSpan?.status = SpanStatus.aborted();

      return result;
    } catch (exception) {
      parentSpan?.throwable = exception;
      parentSpan?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await parentSpan?.finish();
    }
  }
}
