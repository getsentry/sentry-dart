import 'sentry_attachment/sentry_attachment.dart';

class Hint {
  Map<String, Object> internalStorage = {};

  // Objects

  void set(String key, Object value) {
    internalStorage[key] = value;
  }

  Object? get(String key) {
    return internalStorage[key];
  }

  Object? remove(String key) {
    return internalStorage.remove(key);
  }

  void clear() {
    internalStorage.clear();
  }
}
