extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) predicate) {
    for (var item in this) {
      if (predicate(item)) return item;
    }
    return null;
  }
}
