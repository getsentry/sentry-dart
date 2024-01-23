import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_span_helper.dart';

// ignore: implementation_imports
import 'package:hive/src/box_collection/box_collection_stub.dart' as stub;

// ignore: implementation_imports
import 'package:hive/src/box_collection/box_collection_stub.dart'
    if (dart.library.html) 'package:hive/src/box_collection/box_collection_indexed_db.dart'
    if (dart.library.io) 'package:hive/src/box_collection/box_collection.dart'
    as impl;

/// Use instead of [BoxCollection] to add automatic tracing.
class SentryBoxCollection implements stub.BoxCollection {
  final impl.BoxCollection _boxCollection;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbHiveBoxCollection,
  );

  /// Init with [impl.BoxCollection]
  SentryBoxCollection(this._boxCollection);

  @override
  Set<String> get boxNames => _boxCollection.boxNames;

  @override
  void close() {
    _boxCollection.close();
  }

  /// @nodoc
  @internal
  void setHub(Hub hub) {
    _spanHelper.setHub(hub);
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
    final spanHelper = SentrySpanHelper(
      // ignore: invalid_use_of_internal_member
      SentryTraceOrigins.autoDbHiveBoxCollection,
    );
    spanHelper.setHub(hub ?? HubAdapter());

    return await spanHelper.asyncWrapInSpan(
      'open',
      () async {
        final boxCollection = await impl.BoxCollection.open(
          name,
          boxNames,
          path: path,
          key: key,
        );
        final sbc = SentryBoxCollection(boxCollection);
        sbc.setHub(hub ?? HubAdapter());
        return sbc;
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
