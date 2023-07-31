import 'package:meta/meta.dart';

@internal
class IterableUtils<T> {
  IterableUtils(this.iterable);

  Iterable<T>? iterable;

  T? firstWhereOrNull(bool Function(T item) predicate) {
    final iterable = this.iterable;
    if (iterable == null) {
      return null;
    }
    for (var item in iterable) {
      if (predicate(item)) return item;
    }
    return null;
  }
}
