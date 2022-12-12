/// Hints are used in [BeforeSendCallback], [BeforeBreadcrumbCallback] and
/// event processors.
///
/// Event and breadcrumb hints are objects containing various information used
/// to put together an event or a breadcrumb. Typically hints hold the original
/// exception so that additional data can be extracted or grouping can be
/// affected.
class Hint {
  final Map<String, Object> _internalStorage = {};

  Hint();

  factory Hint.withMap(Map<String, Object> map) {
    final hint = Hint();
    hint.addAll(map);
    return hint;
  }

  // Objects

  void addAll(Map<String, Object> keysAndValues) {
    _internalStorage.addAll(keysAndValues);
  }

  void set(String key, Object value) {
    _internalStorage[key] = value;
  }

  Object? get(String key) {
    return _internalStorage[key];
  }

  void remove(String key) {
    _internalStorage.remove(key);
  }

  void clear() {
    _internalStorage.clear();
  }
}
