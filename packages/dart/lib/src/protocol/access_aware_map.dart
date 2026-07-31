import 'dart:collection';

import 'package:meta/meta.dart';

import '../utils/internal_logger.dart';

/// Tracks which keys were read, so the ones that were not can be preserved as
/// unknown fields and round-trip untouched.
///
/// The value type is `Object?` rather than `dynamic` deliberately: it makes an
/// unchecked read a compile-time error, so every field has to go through the
/// typed readers in [JsonReaders].
@internal
class AccessAwareMap extends MapBase<String, Object?> {
  AccessAwareMap(this._map);

  final Map<String, Object?> _map;
  final Set<String> _accessedKeysWithValues = {};

  Set<String> get accessedKeysWithValues => _accessedKeysWithValues;

  /// Reads [key] without marking it as accessed.
  Object? peek(String key) => _map[key];

  /// Marks [key] as accessed, so it is excluded from [notAccessed].
  ///
  /// Keys absent from the map are never marked — marking them would let
  /// [notAccessed] mistake the map for fully consumed.
  void markAccessed(String key) {
    if (_map.containsKey(key)) {
      _accessedKeysWithValues.add(key);
    }
  }

  /// Undoes [markAccessed], so [notAccessed] reports [key] again.
  void unmarkAccessed(String key) => _accessedKeysWithValues.remove(key);

  @override
  Object? operator [](Object? key) {
    if (key is String) {
      markAccessed(key);
    }
    return _map[key];
  }

  @override
  void operator []=(String key, Object? value) {
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
  Object? remove(Object? key) {
    return _map.remove(key);
  }

  Map<String, Object?>? notAccessed() {
    if (_accessedKeysWithValues.length == _map.length) {
      return null;
    }
    Map<String, Object?> unknown = _map.keys
        .where((key) => !_accessedKeysWithValues.contains(key))
        .fold<Map<String, Object?>>({}, (map, key) {
          map[key] = _map[key];
          return map;
        });
    return unknown.isNotEmpty ? unknown : null;
  }
}

/// 2^53 — the largest integer a double represents exactly, on web too.
const _maxExactIntegerAsDouble = 9007199254740992.0;

/// Type-safe reads of untrusted JSON values.
///
/// A value that does not match the expected wire type is not fatal: the read
/// returns `null` and the key stays unaccessed, so the raw value survives in
/// [AccessAwareMap.notAccessed] and round-trips instead of being dropped.
@internal
extension JsonReaders on AccessAwareMap {
  String? readString(String key) =>
      _read(key, 'String', (raw) => raw is String ? raw : null);

  /// Reads a double, optionally constrained to [min]..[max] inclusive. A value
  /// outside the range is treated exactly like a type mismatch.
  double? readDouble(String key, {double? min, double? max}) => _read(
    key,
    min == null && max == null ? 'double' : 'double in $min..$max',
    (raw) {
      if (raw is! num || !raw.isFinite) {
        return null;
      }
      final value = raw.toDouble();
      if ((min != null && value < min) || (max != null && value > max)) {
        return null;
      }
      return value;
    },
  );

  int? readInt(String key) => _read(key, 'int', _asInt);

  int? _asInt(Object raw) => switch (raw) {
    final int value => value,
    // Only integral doubles within exact integer precision convert; beyond
    // that `toInt()` clamps, and a fractional value is not an int at all.
    final double value
        when value.isFinite &&
            value == value.truncateToDouble() &&
            value.abs() <= _maxExactIntegerAsDouble =>
      value.toInt(),
    _ => null,
  };

  bool? readBool(String key) => _read(
    key,
    'bool',
    (raw) => switch (raw) {
      final bool value => value,
      // Native bridges report booleans as 0/1.
      final num value when value == 0 || value == 1 => value == 1,
      _ => null,
    },
  );

  DateTime? readDateTime(String key) => _read(
    key,
    'ISO-8601 String',
    (raw) => raw is String ? DateTime.tryParse(raw) : null,
  );

  /// A nested JSON object, re-keyed to `String` so native maps are accepted.
  Map<String, Object?>? readMap(String key) =>
      _read(key, 'Map', _toStringKeyedMap);

  Map<String, String>? readStringMap(String key) =>
      _read(key, 'Map<String, String>', (raw) {
        final map = _toStringKeyedMap(raw);
        if (map == null) return null;
        final result = <String, String>{};
        for (final entry in map.entries) {
          final value = entry.value;
          if (value is String) {
            result[entry.key] = value;
          }
        }
        _logDropped(key, map.length - result.length, 'String');
        return result;
      });

  /// A nested JSON object deserialized by [fromJson].
  ///
  /// A child [fromJson] cannot build at all — a required field missing, or a
  /// value its constructor rejects — is dropped rather than fatal, and its raw
  /// value stays in [AccessAwareMap.notAccessed] so it still round-trips.
  T? readObject<T>(String key, T Function(Map<String, Object?> json) fromJson) {
    final map = readMap(key);
    // An empty object carries no fields to build from.
    if (map == null || map.isEmpty) {
      return null;
    }
    try {
      return fromJson(map);
    } catch (exception, stackTrace) {
      internalLogger.warning(
        () => 'Failed to deserialize JSON key "$key", keeping the raw value',
        error: exception,
        stackTrace: stackTrace,
      );
      unmarkAccessed(key);
      return null;
    }
  }

  List<T>? readObjectList<T>(
    String key,
    T Function(Map<String, Object?> json) fromJson,
  ) {
    final maps = readMapList(key);
    if (maps == null) {
      return null;
    }
    final result = <T>[];
    for (final map in maps) {
      try {
        result.add(fromJson(map));
      } catch (exception, stackTrace) {
        internalLogger.warning(
          () =>
              'Failed to deserialize an element of JSON key "$key", '
              'dropping it',
          error: exception,
          stackTrace: stackTrace,
        );
      }
    }
    return List<T>.of(result, growable: false);
  }

  /// A JSON array of free-form values, kept as-is — including nulls, which are
  /// meaningful when the element type is unconstrained.
  List<Object?>? readList(String key) =>
      _read(key, 'List', (raw) => raw is List ? List<Object?>.from(raw) : null);

  List<int>? readIntList(String key) => _readList(key, 'int', _asInt);

  List<String>? readStringList(String key) =>
      _readList(key, 'String', (element) => element is String ? element : null);

  List<Map<String, Object?>>? readMapList(String key) =>
      _readList(key, 'Map', _toStringKeyedMap);

  /// Lists are filtered element-wise: an element that does not convert is
  /// dropped and logged. Partial survival cannot be expressed in
  /// [AccessAwareMap.notAccessed], so one bad element never costs the rest.
  List<E>? _readList<E extends Object>(
    String key,
    String elementType,
    E? Function(Object element) convert,
  ) => _read(key, 'List<$elementType>', (raw) {
    if (raw is! List) return null;
    final result = <E>[];
    for (final element in raw) {
      final converted = element == null ? null : convert(element);
      if (converted != null) {
        result.add(converted);
      }
    }
    _logDropped(key, raw.length - result.length, elementType);
    return result;
  });

  Map<String, Object?>? _toStringKeyedMap(Object raw) {
    if (raw is! Map) return null;
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) return null;
      result[key] = entry.value;
    }
    return result;
  }

  void _logDropped(String key, int count, String expected) {
    if (count == 0) return;
    internalLogger.warning(
      () =>
          'Type mismatch in JSON deserialization: key "$key" dropped $count '
          'entr${count == 1 ? 'y' : 'ies'} that is not $expected',
    );
  }

  T? _read<T extends Object>(
    String key,
    String expected,
    T? Function(Object raw) convert,
  ) {
    final Object? raw = peek(key);
    if (raw == null) {
      markAccessed(key);
      return null;
    }
    final value = convert(raw);
    if (value == null) {
      internalLogger.warning(
        () =>
            'Type mismatch in JSON deserialization: key "$key" expected '
            '$expected but got ${raw.runtimeType}',
      );
      // NaN and Infinity have no JSON representation, so letting them survive
      // in `notAccessed()` would make encoding the payload throw.
      if (raw is double && !raw.isFinite) {
        markAccessed(key);
      }
      return null;
    }
    markAccessed(key);
    return value;
  }
}
