import 'dart:collection';

import 'package:meta/meta.dart';

@internal
class AccessAwareMap<K, V> extends MapBase<K, V> {
  AccessAwareMap(this._map);

  final Map<K, V> _map;
  final Set<K> _accessedKeysWithValues = {};

  Set<K> get accessedKeysWithValues => _accessedKeysWithValues;

  @override
  V? operator [](Object? key) {
    if (key is K && _map.containsKey(key)) {
      _accessedKeysWithValues.add(key);
    }
    return _map[key];
  }

  @override
  void operator []=(K key, V value) {
    _map[key] = value;
  }

  @override
  void clear() {
    _map.clear();
    _accessedKeysWithValues.clear();
  }

  @override
  Iterable<K> get keys => _map.keys;

  @override
  V? remove(Object? key) {
    return _map.remove(key);
  }

  Map<K, dynamic>? notAccessed() {
    if (_accessedKeysWithValues.length == _map.length) {
      return null;
    }
    Map<K, dynamic> unknown = _map.keys
        .where((key) => !_accessedKeysWithValues.contains(key))
        .fold<Map<K, dynamic>>({}, (map, key) {
      map[key] = _map[key];
      return map;
    });
    return unknown.isNotEmpty ? unknown : null;
  }
}
