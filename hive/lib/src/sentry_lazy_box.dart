import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_hive_impl.dart';

import 'sentry_box_base.dart';

/// @nodoc
@internal
class SentryLazyBox<E> extends SentryBoxBase<E> implements LazyBox<E> {
  final LazyBox<E> _lazyBox;
  final Hub _hub;

  /// @nodoc
  SentryLazyBox(this._lazyBox, @internal this._hub) : super(_lazyBox, _hub);

  @override
  Future<E?> get(key, {E? defaultValue}) {
    return _asyncWrapInSpan('get', () async {
      return await _lazyBox.get(key, defaultValue: defaultValue);
    });
  }

  @override
  Future<E?> getAt(int index) {
    return _asyncWrapInSpan('getAt', () async {
      return _lazyBox.getAt(index);
    });
  }

  // Helper

  Future<T> _asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute,
  ) async {
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryHiveImpl.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = SentryTraceOrigins.autoDbHiveLazyBox;

    span?.setData(SentryHiveImpl.dbSystemKey, SentryHiveImpl.dbSystem);
    span?.setData(SentryHiveImpl.dbNameKey, name);

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
