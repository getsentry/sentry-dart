import 'dart:collection';

import 'package:meta/meta.dart';

@internal
class AccessAwareMap<String, V> extends MapBase<String, V> {
  AccessAwareMap(this._map);

  final Map<String, V> _map;
  final Set<String> _accessedKeys = {};

  Set<String> get accessedKeys => _accessedKeys;

  @override
  V? operator [](Object? key) {
    if (key is String) {
      _accessedKeys.add(key);
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
    _accessedKeys.clear();
  }

  @override
  Iterable<String> get keys => _map.keys;

  @override
  V? remove(Object? key) {
    return _map.remove(key);
  }

  Map<String, dynamic>? notAccessed() {
    Map<String, dynamic> unknown = _map.keys
        .where((key) => !accessedKeys.contains(key))
        .fold<Map<String, dynamic>>({}, (map, key) {
      map[key] = _map[key];
      return map;
    });
    return unknown.isNotEmpty ? unknown : null;
  }
}
