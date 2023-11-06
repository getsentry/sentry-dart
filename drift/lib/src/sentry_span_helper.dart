import 'package:meta/meta.dart';

import 'package:sentry/sentry.dart';

import 'sentry_query_executor.dart';

/// @nodoc
@internal
class SentrySpanHelper {
  /// @nodoc
  Hub _hub = HubAdapter();

  /// @nodoc
  final String _origin;

  /// @nodoc
  SentrySpanHelper(this._origin);

  /// @nodoc
  void setHub(Hub hub) {
    _hub = hub;
  }

  /// @nodoc
  @internal
  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
  }) async {
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryQueryExecutor.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(
        SentryQueryExecutor.dbSystemKey, SentryQueryExecutor.dbSystem,);

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

  /// This span is used for the database transaction.
  @internal
  ISentrySpan? transactionSpan;

  /// @nodoc
  @internal
  T beginTransaction<T>(
    String description,
    T Function() execute, {
    String? dbName,
  }) {
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryQueryExecutor.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(
        SentryQueryExecutor.dbSystemKey, SentryQueryExecutor.dbSystem,);

    if (dbName != null) {
      span?.setData(SentryQueryExecutor.dbNameKey, dbName);
    }

    try {
      final result = execute();
      span?.status = SpanStatus.unknown();

      return result;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      transactionSpan = span;
    }
  }

  /// @nodoc
  @internal
  Future<T> finishTransaction<T>(
    Future<T> Function() execute, {
    String? dbName,
  }) async {
    try {
      final result = await execute();
      transactionSpan?.status = SpanStatus.ok();

      return result;
    } catch (exception) {
      transactionSpan?.throwable = exception;
      transactionSpan?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await transactionSpan?.finish();
      transactionSpan = null;
    }
  }

  /// @nodoc
  @internal
  Future<T> abortTransaction<T>(
    Future<T> Function() execute, {
    String? dbName,
  }) async {
    try {
      final result = await execute();
      transactionSpan?.status = SpanStatus.aborted();

      return result;
    } catch (exception) {
      transactionSpan?.throwable = exception;
      transactionSpan?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await transactionSpan?.finish();
      transactionSpan = null;
    }
  }
}
