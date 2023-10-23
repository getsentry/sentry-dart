import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_hive_impl.dart';

/// @nodoc
@internal
class SentryBoxBase<E> implements BoxBase<E> {
  final BoxBase<E> _boxBase;
  final Hub _hub;

  /// @nodoc
  SentryBoxBase(this._boxBase, this._hub);

  @override
  Future<int> add(E value) async {
    return _asyncWrapInSpan('add', () async {
      try {
        return await _boxBase.add(value);
      } catch (error) {
        rethrow;
      }
    });
  }

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) {
    return _asyncWrapInSpan('addAll', () async {
      return await _boxBase.addAll(values);
    });
  }

  @override
  Future<int> clear() {
    return _asyncWrapInSpan('clear', () async {
      return await _boxBase.clear();
    });
  }

  @override
  Future<void> close() {
    return _asyncWrapInSpan('close', () async {
      return await _boxBase.close();
    });
  }

  @override
  Future<void> compact() {
    return _asyncWrapInSpan('compact', () async {
      return await _boxBase.compact();
    });
  }

  @override
  bool containsKey(key) {
    return _boxBase.containsKey(key);
  }

  @override
  Future<void> delete(key) {
    return _asyncWrapInSpan('delete', () async {
      return await _boxBase.delete(key);
    });
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) {
    return _asyncWrapInSpan('deleteAll', () async {
      return await _boxBase.deleteAll(keys);
    });
  }

  @override
  Future<void> deleteAt(int index) {
    return _asyncWrapInSpan('deleteAt', () async {
      return await _boxBase.deleteAt(index);
    });
  }

  @override
  Future<void> deleteFromDisk() {
    return _asyncWrapInSpan('deleteFromDisk', () async {
      return await _boxBase.deleteFromDisk();
    });
  }

  @override
  Future<void> flush() {
    return _asyncWrapInSpan('flush', () async {
      return await _boxBase.flush();
    });
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
    return _asyncWrapInSpan('put', () async {
      return await _boxBase.put(key, value);
    });
  }

  @override
  Future<void> putAll(Map<dynamic, E> entries) {
    return _asyncWrapInSpan('putAll', () async {
      return await _boxBase.putAll(entries);
    });
  }

  @override
  Future<void> putAt(int index, value) {
    return _asyncWrapInSpan('putAt', () async {
      return await _boxBase.putAt(index, value);
    });
  }

  @override
  Stream<BoxEvent> watch({key}) {
    return _boxBase.watch(key: key);
  }

  // Helper

  Future<T> _asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute,
  ) async {
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      SentryHiveImpl.dbOp,
      description: description,
    );

    // ignore: invalid_use_of_internal_member
    span?.origin = SentryTraceOrigins.autoDbHiveBoxBase;

    span?.setData(SentryHiveImpl.dbSystemKey, SentryHiveImpl.dbSystem);
    span?.setData(SentryHiveImpl.dbNameKey, name);

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
