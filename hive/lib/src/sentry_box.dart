import 'package:meta/meta.dart';
import 'package:hive/hive.dart';
import 'package:sentry/sentry.dart';

import '../sentry_hive.dart';

// ignore: public_member_api_docs
class SentryBox<E> implements Box<E> {

  final Box<E> _box;
  final Hub _hub;

  // ignore: public_member_api_docs
  SentryBox(this._box, @internal Hub? hub) : _hub = hub ?? HubAdapter();

  @override
  Future<int> add(E value) async {
    return _asyncWrapInSpan('add', () async {
        return await _box.add(value);
    });
  }

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) async {
    return _asyncWrapInSpan('addAll', () async {
      return await _box.addAll(values);
    });
  }

  @override
  Future<int> clear() async {
    return _asyncWrapInSpan('clear', () async {
      return await _box.clear();
    });
  }

  @override
  Future<void> close() async {
    return _asyncWrapInSpan('close', () async {
      return await _box.close();
    });
  }

  @override
  Future<void> compact() async {
    return _asyncWrapInSpan('compact', () async {
      return await _box.compact();
    });
  }

  @override
  bool containsKey(key) {
    return _box.containsKey(key);
  }

  @override
  Future<void> delete(key) async {
    return _asyncWrapInSpan('delete', () async {
      return await _box.delete(key);
    });
  }

  @override
  // ignore: strict_raw_type
  Future<void> deleteAll(Iterable keys) async {
    return _asyncWrapInSpan('delete', () async {
      return await _box.deleteAll(keys);
    });
  }

  @override
  Future<void> deleteAt(int index) async {
    return _asyncWrapInSpan('deleteAt', () async {
      return await _box.deleteAt(index);
    });
  }

  @override
  Future<void> deleteFromDisk() async {
    return _asyncWrapInSpan('deleteFromDisk', () async {
      return await _box.deleteFromDisk();
    });
  }

  @override
  Future<void> flush() async {
    return _asyncWrapInSpan('flush', () async {
      return await _box.flush();
    });
  }

  @override
  E? get(key, {E? defaultValue}) {
    return _box.get(key, defaultValue: defaultValue);
  }

  @override
  E? getAt(int index) {
    return _box.getAt(index);
  }

  @override
  bool get isEmpty => _box.isEmpty;

  @override
  bool get isNotEmpty => _box.isNotEmpty;

  @override
  bool get isOpen => _box.isOpen;

  @override
  dynamic keyAt(int index) {
    return _box.keyAt(index);
  }

  @override
  // ignore: strict_raw_type
  Iterable get keys => _box.keys;

  @override
  bool get lazy => _box.lazy;

  @override
  int get length => _box.length;

  @override
  String get name => _box.name;

  @override
  String? get path => _box.path;

  @override
  Future<void> put(key, E value) async {
    return _asyncWrapInSpan('put', () async {
      return await _box.put(key, value);
    });
  }

  @override
  Future<void> putAll(Map<dynamic, E> entries) async {
    return _asyncWrapInSpan('putAll', () async {
      return await _box.putAll(entries);
    });
  }

  @override
  Future<void> putAt(int index, E value) async {
    return _asyncWrapInSpan('putAt', () async {
      return await _box.putAt(index, value);
    });
  }

  @override
  Map<dynamic, E> toMap() {
    return _box.toMap();
  }

  @override
  Iterable<E> get values => _box.values;

  @override
  Iterable<E> valuesBetween({startKey, endKey}) {
    return _box.valuesBetween(startKey: startKey, endKey: endKey);
  }

  @override
  Stream<BoxEvent> watch({key}) {
    return _box.watch(key: key);
  }

  // Helper

  Future<T> _asyncWrapInSpan<T>(String description, Future<T> Function() execute) async {
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryHive.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = SentryTraceOrigins.autoDbHiveBox;

    span?.setData(SentryHive.dbSystemKey, SentryHive.dbSystem);
    span?.setData(SentryHive.dbNameKey, name);

    try {
      final result = await execute();
      span?.status = SpanStatus.ok();

      return result;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await span?.finish();
    }
  }
}
