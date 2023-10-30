import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_span_helper.dart';

/// @nodoc
@internal
class SentryBoxBase<E> implements BoxBase<E> {
  final BoxBase<E> _boxBase;
  final Hub _hub;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbHiveBoxBase,
  );

  /// @nodoc
  SentryBoxBase(this._boxBase, this._hub) {
    _spanHelper.setHub(this._hub);
  }

  @override
  Future<int> add(E value) async {
    return _spanHelper.asyncWrapInSpan(
      'add',
      () async {
        return await _boxBase.add(value);
      },
      dbName: name,
    );
  }

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) {
    return _spanHelper.asyncWrapInSpan(
      'addAll',
      () async {
        return await _boxBase.addAll(values);
      },
      dbName: name,
    );
  }

  @override
  Future<int> clear() {
    return _spanHelper.asyncWrapInSpan(
      'clear',
      () async {
        return await _boxBase.clear();
      },
      dbName: name,
    );
  }

  @override
  Future<void> close() {
    return _spanHelper.asyncWrapInSpan(
      'close',
      () async {
        return await _boxBase.close();
      },
      dbName: name,
    );
  }

  @override
  Future<void> compact() {
    return _spanHelper.asyncWrapInSpan(
      'compact',
      () async {
        return await _boxBase.compact();
      },
      dbName: name,
    );
  }

  @override
  bool containsKey(key) {
    return _boxBase.containsKey(key);
  }

  @override
  Future<void> delete(key) {
    return _spanHelper.asyncWrapInSpan(
      'delete',
      () async {
        return await _boxBase.delete(key);
      },
      dbName: name,
    );
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) {
    return _spanHelper.asyncWrapInSpan(
      'deleteAll',
      () async {
        return await _boxBase.deleteAll(keys);
      },
      dbName: name,
    );
  }

  @override
  Future<void> deleteAt(int index) {
    return _spanHelper.asyncWrapInSpan(
      'deleteAt',
      () async {
        return await _boxBase.deleteAt(index);
      },
      dbName: name,
    );
  }

  @override
  Future<void> deleteFromDisk() {
    return _spanHelper.asyncWrapInSpan(
      'deleteFromDisk',
      () async {
        return await _boxBase.deleteFromDisk();
      },
      dbName: name,
    );
  }

  @override
  Future<void> flush() {
    return _spanHelper.asyncWrapInSpan(
      'flush',
      () async {
        return await _boxBase.flush();
      },
      dbName: name,
    );
  }

  @override
  bool get isEmpty => _boxBase.isEmpty;

  @override
  bool get isNotEmpty => _boxBase.isNotEmpty;

  @override
  bool get isOpen => _boxBase.isOpen;

  @override
  keyAt(int index) {
    return _boxBase.keyAt(index);
  }

  @override
  Iterable<dynamic> get keys => _boxBase.keys;

  @override
  bool get lazy => _boxBase.lazy;

  @override
  int get length => _boxBase.length;

  @override
  String get name => _boxBase.name;

  @override
  String? get path => _boxBase.path;

  @override
  Future<void> put(key, value) {
    return _spanHelper.asyncWrapInSpan(
      'put',
      () async {
        return await _boxBase.put(key, value);
      },
      dbName: name,
    );
  }

  @override
  Future<void> putAll(Map<dynamic, E> entries) {
    return _spanHelper.asyncWrapInSpan(
      'putAll',
      () async {
        return await _boxBase.putAll(entries);
      },
      dbName: name,
    );
  }

  @override
  Future<void> putAt(int index, value) {
    return _spanHelper.asyncWrapInSpan(
      'putAt',
      () async {
        return await _boxBase.putAt(index, value);
      },
      dbName: name,
    );
  }

  @override
  Stream<BoxEvent> watch({key}) {
    return _boxBase.watch(key: key);
  }
}
