import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/box_collection/box_collection_stub.dart'
    if (dart.library.js_interop) 'package:hive/src/box_collection/box_collection_indexed_db.dart'
    if (dart.library.io) 'package:hive/src/box_collection/box_collection.dart'
    as impl;
// ignore: implementation_imports
import 'package:hive/src/box_collection/box_collection_stub.dart' as stub;
import 'package:sentry/sentry.dart';

import 'sentry_span_helper.dart';

/// Use instead of [BoxCollection] to add automatic tracing.
class SentryBoxCollection implements stub.BoxCollection {
  final impl.BoxCollection _boxCollection;

  late final SentrySpanHelper _spanHelper;

  /// Init with [impl.BoxCollection]
  SentryBoxCollection(this._boxCollection, {Hub? hub}) {
    _spanHelper = SentrySpanHelper(
      // ignore: invalid_use_of_internal_member
      SentryTraceOrigins.autoDbHiveBoxCollection,
      hub: hub ?? HubAdapter(),
    );
  }

  @override
  Set<String> get boxNames => _boxCollection.boxNames;

  @override
  void close() {
    _boxCollection.close();
  }

  @override
  Future<void> deleteFromDisk() {
    return _spanHelper.asyncWrapInSpan(
      'deleteFromDisk',
      () {
        return _boxCollection.deleteFromDisk();
      },
      dbName: name,
    );
  }

  @override
  String get name => _boxCollection.name;

  // ignore: public_member_api_docs
  static Future<SentryBoxCollection> open(
    String name,
    Set<String> boxNames, {
    String? path,
    HiveCipher? key,
    Hub? hub,
  }) async {
    final resolvedHub = hub ?? HubAdapter();
    final spanHelper = SentrySpanHelper(
      // ignore: invalid_use_of_internal_member
      SentryTraceOrigins.autoDbHiveBoxCollection,
      hub: resolvedHub,
    );

    return await spanHelper.asyncWrapInSpan(
      'open',
      () async {
        final boxCollection = await impl.BoxCollection.open(
          name,
          boxNames,
          path: path,
          key: key,
        );
        return SentryBoxCollection(boxCollection, hub: resolvedHub);
      },
      dbName: name,
    );
  }

  @override
  Future<stub.CollectionBox<V>> openBox<V>(
    String name, {
    bool preload = false,
    stub.CollectionBox<V> Function(String p1, stub.BoxCollection p2)?
        boxCreator,
  }) {
    return _spanHelper.asyncWrapInSpan(
      'openBox',
      () {
        return _boxCollection.openBox(
          name,
          preload: preload,
          boxCreator: boxCreator,
        );
      },
      dbName: this.name,
    );
  }

  @override
  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  }) async {
    return await _spanHelper.asyncWrapInSpan(
      'transaction',
      () {
        return _boxCollection.transaction(
          action,
          boxNames: boxNames,
          readOnly: readOnly,
        );
      },
      dbName: name,
    );
  }
}
