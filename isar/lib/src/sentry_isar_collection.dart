import 'dart:typed_data';
import 'package:isar/isar.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_span_helper.dart';

/// Sentry wrapper around IsarCollection
@experimental
class SentryIsarCollection<OBJ> implements IsarCollection<OBJ> {
  final IsarCollection<OBJ> _isarCollection;
  final Hub _hub;
  final String _dbName;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbIsarCollection,
  );

  /// ctor of SentryIsarCollection
  SentryIsarCollection(this._isarCollection, this._hub, this._dbName) {
    _spanHelper.setHub(_hub);
  }

  @override
  Query<R> buildQuery<R>({
    List<WhereClause> whereClauses = const [],
    bool whereDistinct = false,
    Sort whereSort = Sort.asc,
    FilterOperation? filter,
    List<SortProperty> sortBy = const [],
    List<DistinctProperty> distinctBy = const [],
    int? offset,
    int? limit,
    String? property,
  }) {
    return _isarCollection.buildQuery(
      whereClauses: whereClauses,
      whereDistinct: whereDistinct,
      whereSort: whereSort,
      filter: filter,
      sortBy: sortBy,
      distinctBy: distinctBy,
      offset: offset,
      limit: limit,
      property: property,
    );
  }

  @override
  Future<void> clear() {
    return _spanHelper.asyncWrapInSpan(
      'clear',
      () {
        return _isarCollection.clear();
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  void clearSync() {
    _isarCollection.clearSync();
  }

  @override
  Future<int> count() {
    return _spanHelper.asyncWrapInSpan(
      'count',
      () {
        return _isarCollection.count();
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  int countSync() {
    return _isarCollection.countSync();
  }

  @override
  Future<bool> delete(Id id) {
    return _spanHelper.asyncWrapInSpan(
      'delete',
      () {
        return _isarCollection.delete(id);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Future<int> deleteAll(List<Id> ids) {
    return _spanHelper.asyncWrapInSpan(
      'deleteAll',
      () {
        return _isarCollection.deleteAll(ids);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Future<int> deleteAllByIndex(String indexName, List<IndexKey> keys) {
    return _spanHelper.asyncWrapInSpan(
      'deleteAllByIndex',
      () {
        return _isarCollection.deleteAllByIndex(indexName, keys);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  int deleteAllByIndexSync(String indexName, List<IndexKey> keys) {
    return _isarCollection.deleteAllByIndexSync(indexName, keys);
  }

  @override
  int deleteAllSync(List<Id> ids) {
    return _isarCollection.deleteAllSync(ids);
  }

  @override
  Future<bool> deleteByIndex(String indexName, IndexKey key) {
    return _spanHelper.asyncWrapInSpan(
      'deleteByIndex',
      () {
        return _isarCollection.deleteByIndex(indexName, key);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  bool deleteByIndexSync(String indexName, IndexKey key) {
    return _isarCollection.deleteByIndexSync(indexName, key);
  }

  @override
  bool deleteSync(Id id) {
    return _isarCollection.deleteSync(id);
  }

  @override
  QueryBuilder<OBJ, OBJ, QFilterCondition> filter() {
    return _isarCollection.filter();
  }

  @override
  Future<OBJ?> get(Id id) {
    return _spanHelper.asyncWrapInSpan(
      'get',
      () {
        return _isarCollection.get(id);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Future<List<OBJ?>> getAll(List<Id> ids) {
    return _spanHelper.asyncWrapInSpan(
      'getAll',
      () {
        return _isarCollection.getAll(ids);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Future<List<OBJ?>> getAllByIndex(String indexName, List<IndexKey> keys) {
    return _spanHelper.asyncWrapInSpan(
      'getAllByIndex',
      () {
        return _isarCollection.getAllByIndex(indexName, keys);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  List<OBJ?> getAllByIndexSync(String indexName, List<IndexKey> keys) {
    return _isarCollection.getAllByIndexSync(indexName, keys);
  }

  @override
  List<OBJ?> getAllSync(List<Id> ids) {
    return _isarCollection.getAllSync(ids);
  }

  @override
  Future<OBJ?> getByIndex(String indexName, IndexKey key) {
    return _spanHelper.asyncWrapInSpan(
      'getByIndex',
      () {
        return _isarCollection.getByIndex(indexName, key);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  OBJ? getByIndexSync(String indexName, IndexKey key) {
    return _isarCollection.getByIndexSync(indexName, key);
  }

  @override
  Future<int> getSize({
    bool includeIndexes = false,
    bool includeLinks = false,
  }) {
    return _spanHelper.asyncWrapInSpan(
      'getSize',
      () {
        return _isarCollection.getSize(
          includeIndexes: includeIndexes,
          includeLinks: includeLinks,
        );
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  int getSizeSync({bool includeIndexes = false, bool includeLinks = false}) {
    return _isarCollection.getSizeSync(
      includeIndexes: includeIndexes,
      includeLinks: includeLinks,
    );
  }

  @override
  OBJ? getSync(Id id) {
    return _isarCollection.getSync(id);
  }

  @override
  Future<void> importJson(List<Map<String, dynamic>> json) {
    return _spanHelper.asyncWrapInSpan(
      'importJson',
      () {
        return _isarCollection.importJson(json);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Future<void> importJsonRaw(Uint8List jsonBytes) {
    return _spanHelper.asyncWrapInSpan(
      'importJsonRaw',
      () {
        return _isarCollection.importJsonRaw(jsonBytes);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  void importJsonRawSync(Uint8List jsonBytes) {
    _isarCollection.importJsonRawSync(jsonBytes);
  }

  @override
  void importJsonSync(List<Map<String, dynamic>> json) {
    _isarCollection.importJsonSync(json);
  }

  @override
  Isar get isar => _isarCollection.isar;

  @override
  String get name => _isarCollection.name;

  @override
  Future<Id> put(OBJ object) {
    return _spanHelper.asyncWrapInSpan(
      'put',
      () {
        return _isarCollection.put(object);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Future<List<Id>> putAll(List<OBJ> objects) {
    return _spanHelper.asyncWrapInSpan(
      'putAll',
      () {
        return _isarCollection.putAll(objects);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Future<List<Id>> putAllByIndex(String indexName, List<OBJ> objects) {
    return _spanHelper.asyncWrapInSpan(
      'putAllByIndex',
      () {
        return _isarCollection.putAllByIndex(indexName, objects);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  List<Id> putAllByIndexSync(
    String indexName,
    List<OBJ> objects, {
    bool saveLinks = true,
  }) {
    return _isarCollection.putAllByIndexSync(
      indexName,
      objects,
      saveLinks: saveLinks,
    );
  }

  @override
  List<Id> putAllSync(List<OBJ> objects, {bool saveLinks = true}) {
    return _isarCollection.putAllSync(objects, saveLinks: saveLinks);
  }

  @override
  Future<Id> putByIndex(String indexName, OBJ object) {
    return _spanHelper.asyncWrapInSpan(
      'putByIndex',
      () {
        return _isarCollection.putByIndex(indexName, object);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Id putByIndexSync(String indexName, OBJ object, {bool saveLinks = true}) {
    return _isarCollection.putByIndexSync(
      indexName,
      object,
      saveLinks: saveLinks,
    );
  }

  @override
  Id putSync(OBJ object, {bool saveLinks = true}) {
    return _isarCollection.putSync(object, saveLinks: saveLinks);
  }

  @override
  CollectionSchema<OBJ> get schema => _isarCollection.schema;

  @override
  @visibleForTesting
  @experimental
  Future<void> verify(List<OBJ> objects) {
    return _spanHelper.asyncWrapInSpan(
      'verify',
      () {
        // ignore: invalid_use_of_visible_for_testing_member
        return _isarCollection.verify(objects);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  @visibleForTesting
  @experimental
  Future<void> verifyLink(
    String linkName,
    List<int> sourceIds,
    List<int> targetIds,
  ) {
    return _spanHelper.asyncWrapInSpan(
      'verifyLink',
      () {
        // ignore: invalid_use_of_visible_for_testing_member
        return _isarCollection.verifyLink(linkName, sourceIds, targetIds);
      },
      dbName: _dbName,
      collectionName: name,
    );
  }

  @override
  Stream<void> watchLazy({bool fireImmediately = false}) {
    return _isarCollection.watchLazy(fireImmediately: fireImmediately);
  }

  @override
  Stream<OBJ?> watchObject(Id id, {bool fireImmediately = false}) {
    return _isarCollection.watchObject(id, fireImmediately: fireImmediately);
  }

  @override
  Stream<void> watchObjectLazy(Id id, {bool fireImmediately = false}) {
    return _isarCollection.watchObjectLazy(
      id,
      fireImmediately: fireImmediately,
    );
  }

  @override
  QueryBuilder<OBJ, OBJ, QWhere> where({
    bool distinct = false,
    Sort sort = Sort.asc,
  }) {
    return _isarCollection.where(distinct: distinct, sort: sort);
  }
}
