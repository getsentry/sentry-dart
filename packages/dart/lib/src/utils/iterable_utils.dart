import 'package:meta/meta.dart';

@internal
abstract final class SentryIterableUtils {
  static T? firstOrNull<T>(Iterable<T> iterable) {
    final iterator = iterable.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }

  static T? firstWhereOrNull<T>(
    Iterable<T> iterable,
    bool Function(T item) test,
  ) {
    for (var item in iterable) {
      if (test(item)) return item;
    }
    return null;
  }
}
