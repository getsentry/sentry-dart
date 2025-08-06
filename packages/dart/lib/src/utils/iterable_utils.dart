import 'package:meta/meta.dart';

@internal
class IterableUtils {
  static T? firstWhereOrNull<T>(
    Iterable<T>? iterable,
    bool Function(T item) test,
  ) {
    if (iterable == null) {
      return null;
    }
    for (var item in iterable) {
      if (test(item)) return item;
    }
    return null;
  }
}
