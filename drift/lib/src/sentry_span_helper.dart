import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart' as constants;

@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  ISentrySpan? _parentSpan;

  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter();

  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
  }) async {
    final currentSpan = _parentSpan ?? _hub.getSpan();
    final span = currentSpan?.startChild(
      constants.dbSqlQueryOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(
      constants.dbSystemKey,
      constants.dbSystem,
    );

    if (dbName != null) {
      span?.setData(constants.dbNameKey, dbName);
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
      constants.dbSqlTransactionOp,
      description: 'Begin transaction',
    );

    // ignore: invalid_use_of_internal_member
    _parentSpan?.origin = _origin;

    _parentSpan?.setData(
      constants.dbSystemKey,
      constants.dbSystem,
    );

    if (dbName != null) {
      _parentSpan?.setData(constants.dbNameKey, dbName);
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
