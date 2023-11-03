import 'package:meta/meta.dart';

import 'package:sentry/sentry.dart';

import 'sentry_drift_database.dart';

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
      SentryDriftDatabase.dbOp,
      description: description,
    );

    final breadcrumb = Breadcrumb(
      message: description,
      category: SentryDriftDatabase.dbOp,
      data: {},
      type: 'query',
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(
        SentryDriftDatabase.dbSystemKey, SentryDriftDatabase.dbSystem);

    if (dbName != null) {
      span?.setData(SentryDriftDatabase.dbNameKey, dbName);
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

  @internal
  T beginTransaction<T>(
    String description,
    T Function() execute, {
    String? dbName,
  }) {
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryDriftDatabase.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(
        SentryDriftDatabase.dbSystemKey, SentryDriftDatabase.dbSystem);

    if (dbName != null) {
      span?.setData(SentryDriftDatabase.dbNameKey, dbName);
    }

    try {
      final result = execute();
      span?.status = SpanStatus.unknown();

      return result;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    }
  }

  @internal
  T finishTransaction<T>(
    T Function() execute, {
    String? dbName,
  }) {
    // TODO: is this always the right way to get the current span?
    final span = _hub.getSpan();

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(
        SentryDriftDatabase.dbSystemKey, SentryDriftDatabase.dbSystem);

    if (dbName != null) {
      span?.setData(SentryDriftDatabase.dbNameKey, dbName);
    }

    try {
      final result = execute();
      span?.status = SpanStatus.ok();

      return result;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      span?.finish();
    }
  }
}
