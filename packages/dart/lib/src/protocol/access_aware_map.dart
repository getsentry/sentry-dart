import 'dart:collection';

import 'package:meta/meta.dart';

@internal
class AccessAwareMap<String, V> extends MapBase<String, V> {
  AccessAwareMap(this._map);

  final Map<String, V> _map;
  final Set<String> _accessedKeysWithValues = {};

  Set<String> get accessedKeysWithValues => _accessedKeysWithValues;

  @override
  V? operator [](Object? key) {
    if (key is String && _map.containsKey(key)) {
      _accessedKeysWithValues.add(key);
    }
    return _map[key];
  }

  @override
  void operator []=(String key, V value) {
    _map[key] = value;
  }

  @override
  void clear() {
    _map.clear();
    _accessedKeysWithValues.clear();
  }

  @override
  Iterable<String> get keys => _map.keys;

  @override
  V? remove(Object? key) {
    return _map.remove(key);
  }

  Map<String, dynamic>? notAccessed() {
    if (_accessedKeysWithValues.length == _map.length) {
      return null;
    }
    Map<String, dynamic> unknown = _map.keys
        .where((key) => !_accessedKeysWithValues.contains(key))
        .fold<Map<String, dynamic>>({}, (map, key) {
      map[key] = _map[key];
      return map;
    });
    return unknown.isNotEmpty ? unknown : null;
  }
}
