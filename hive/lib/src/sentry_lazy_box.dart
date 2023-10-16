
import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_box_base.dart';

///
class SentryLazyBox<E> extends SentryBoxBase<E> implements LazyBox<E> {

  final LazyBox<E> _lazyBox;

  ///
  SentryLazyBox(this._lazyBox, @internal Hub hub) : super(_lazyBox, hub);

  @override
  Future<E?> get(key, {E? defaultValue}) {
    return _lazyBox.get(key, defaultValue: defaultValue);
  }

  @override
  Future<E?> getAt(int index) {
    return _lazyBox.getAt(index);
  }
}
