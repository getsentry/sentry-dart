// ignore_for_file: invalid_internal_annotation

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_isar.dart';

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
    String? collectionName,
  }) async {
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryIsar.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(SentryIsar.dbSystemKey, SentryIsar.dbSystem);

    if (dbName != null) {
      span?.setData(SentryIsar.dbNameKey, dbName);
    }

    if (collectionName != null) {
      span?.setData(SentryIsar.dbCollectionKey, collectionName);
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
}
