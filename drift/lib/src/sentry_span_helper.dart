import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_query_executor.dart';

class SentrySpanHelper {
  /// @nodoc
  final Hub _hub;

  /// @nodoc
  final String _origin;

  ISentrySpan? _parentSpan;

  /// @nodoc
  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter();

  /// @nodoc
  @internal
  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
    bool useTransactionSpan = false,
  }) async {
    final currentSpan = _parentSpan ?? _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryQueryExecutor.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(
      SentryQueryExecutor.dbSystemKey,
      SentryQueryExecutor.dbSystem,
    );

    if (dbName != null) {
      span?.setData(SentryQueryExecutor.dbNameKey, dbName);
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

  /// @nodoc
  @internal
  T beginTransaction<T>(
    T Function() execute, {
    String? dbName,
  }) {
    final scopeSpan = _hub.getSpan();
    _parentSpan = scopeSpan?.startChild(
      SentryQueryExecutor.dbOp,
      description: 'Begin transaction',
    );

    // ignore: invalid_use_of_internal_member
    _parentSpan?.origin = _origin;

    _parentSpan?.setData(
      SentryQueryExecutor.dbSystemKey,
      SentryQueryExecutor.dbSystem,
    );

    if (dbName != null) {
      _parentSpan?.setData(SentryQueryExecutor.dbNameKey, dbName);
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

  /// @nodoc
  @internal
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

  /// @nodoc
  @internal
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
