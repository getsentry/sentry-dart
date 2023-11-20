import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_hive_impl.dart';

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
      SentryHiveImpl.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = _origin;

    span?.setData(SentryHiveImpl.dbSystemKey, SentryHiveImpl.dbSystem);

    if (dbName != null) {
      span?.setData(SentryHiveImpl.dbNameKey, dbName);
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
