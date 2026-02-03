import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_box_base.dart';
import 'sentry_span_helper.dart';

/// @nodoc
@internal
class SentryLazyBox<E> extends SentryBoxBase<E> implements LazyBox<E> {
  final LazyBox<E> _lazyBox;
  final Hub _hub;

  late final SentrySpanHelper _spanHelper;

  /// @nodoc
  SentryLazyBox(this._lazyBox, @internal this._hub) : super(_lazyBox, _hub) {
    _spanHelper = SentrySpanHelper(
      // ignore: invalid_use_of_internal_member
      SentryTraceOrigins.autoDbHiveLazyBox,
      hub: _hub,
    );
  }

  @override
  Future<E?> get(key, {E? defaultValue}) {
    return _spanHelper.asyncWrapInSpan(
      'get',
      () {
        return _lazyBox.get(key, defaultValue: defaultValue);
      },
      dbName: name,
    );
  }

  @override
  Future<E?> getAt(int index) {
    return _spanHelper.asyncWrapInSpan(
      'getAt',
      () {
        return _lazyBox.getAt(index);
      },
      dbName: name,
    );
  }
}
