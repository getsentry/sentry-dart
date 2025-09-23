import 'package:meta/meta.dart';
import 'package:hive/hive.dart';
import 'package:sentry/sentry.dart';

import 'sentry_box_base.dart';
import 'sentry_span_helper.dart';

/// @nodoc
@internal
class SentryBox<E> extends SentryBoxBase<E> implements Box<E> {
  final Box<E> _box;
  final Hub _hub;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbHiveBoxBase,
  );

  /// @nodoc
  SentryBox(this._box, @internal this._hub) : super(_box, _hub) {
    _spanHelper.setHub(_hub);
  }

  @override
  E? get(key, {E? defaultValue}) {
    return _spanHelper.syncWrapInSpan(
      'get',
      () {
        return _box.get(key, defaultValue: defaultValue);
      },
      dbName: name,
    );
  }

  @override
  E? getAt(int index) {
    return _spanHelper.syncWrapInSpan(
      'getAt',
      () {
        return _box.getAt(index);
      },
      dbName: name,
    );
  }

  @override
  Map<dynamic, E> toMap() {
    return _box.toMap();
  }

  @override
  Iterable<E> get values => _spanHelper.syncWrapInSpan(
        'values',
        () {
          return _box.values;
        },
        dbName: name,
      );

  @override
  Iterable<E> valuesBetween({startKey, endKey}) {
    return _spanHelper.syncWrapInSpan(
      'valuesBetween',
      () {
        return _box.valuesBetween(startKey: startKey, endKey: endKey);
      },
      dbName: name,
    );
  }
}
