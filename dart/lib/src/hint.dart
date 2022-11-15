class Hint {
  final Map<String, Object> _internalStorage = {};

  // Objects

  void set(String key, Object value) {
    _internalStorage[key] = value;
  }

  Object? get(String key) {
    return _internalStorage[key];
  }

  Object? remove(String key) {
    return _internalStorage.remove(key);
  }

  void clear() {
    _internalStorage.clear();
  }
}
