extension SentryIterableUtils<T> on Iterable<T>? {
  T? get firstOrNull {
    final iterator = this?.iterator;
    if (iterator == null || !iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }

  T? firstWhereOrNull(bool Function(T item) test) {
    final iterable = this;
    if (iterable == null) {
      return null;
    }
    for (var item in iterable) {
      if (test(item)) return item;
    }
    return null;
  }
}
