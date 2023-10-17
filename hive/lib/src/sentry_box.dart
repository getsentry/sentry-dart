import 'package:meta/meta.dart';
import 'package:hive/hive.dart';
import 'package:sentry/sentry.dart';

import 'sentry_box_base.dart';

///
@experimental
class SentryBox<E> extends SentryBoxBase<E> implements Box<E> {

  final Box<E> _box;

  ///
  SentryBox(this._box, @internal Hub hub) : super(_box, hub);

  @override
  E? get(key, {E? defaultValue}) {
    return _box.get(key, defaultValue: defaultValue);
  }

  @override
  E? getAt(int index) {
    return _box.getAt(index);
  }

  @override
  Map<dynamic, E> toMap() {
    return _box.toMap();
  }

  @override
  Iterable<E> get values => _box.values;

  @override
  Iterable<E> valuesBetween({startKey, endKey}) {
    return _box.valuesBetween(startKey: startKey, endKey: endKey);
  }
}
