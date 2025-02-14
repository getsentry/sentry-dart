// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  ISentrySpan? _parentSpan;

  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter() {
    _parentSpan = hub?.getSpan();
  }

  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
    String? operation,
  }) async {
    final span = _parentSpan?.startChild(
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
    final scopeSpan = _hub.getSpan();
    _parentSpan = scopeSpan?.startChild(
      SentrySpanOperations.dbSqlTransaction,
      description: SentrySpanDescriptions.dbTransaction,
    );

    _parentSpan?.origin = _origin;

    _parentSpan?.setData(
      SentrySpanData.dbSystemKey,
      SentrySpanData.dbSystemSqlite,
    );

    if (dbName != null) {
      _parentSpan?.setData(SentrySpanData.dbNameKey, dbName);
    }

    try {
      final result = execute();
      _parentSpan?.status = SpanStatus.unknown();

      return result;
    } catch (exception) {
      _parentSpan?.throwable = exception;
      _parentSpan?.status = SpanStatus.internalError();

      rethrow;
    }
  }

  Future<T> finishTransaction<T>(Future<T> Function() execute) async {
    try {
      final result = await execute();
      _parentSpan?.status = SpanStatus.ok();

      return result;
    } catch (exception) {
      _parentSpan?.throwable = exception;
      _parentSpan?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await _parentSpan?.finish();
      _parentSpan = null;
    }
  }

  Future<T> abortTransaction<T>(Future<T> Function() execute) async {
    try {
      final result = await execute();
      _parentSpan?.status = SpanStatus.aborted();

      return result;
    } catch (exception) {
      _parentSpan?.throwable = exception;
      _parentSpan?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await _parentSpan?.finish();
      _parentSpan = null;
    }
  }
}
