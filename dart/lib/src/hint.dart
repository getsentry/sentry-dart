class Hint {
  final Map<String, Object> _internalStorage = {};

  Hint();

  Hint.fromMap(Map<String, Object> map) {
    _internalStorage.addAll(map);
  }

  // Objects

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
