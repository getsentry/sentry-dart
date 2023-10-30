import 'package:hive/hive.dart';
import 'package:sentry/sentry.dart';

import 'sentry_span_helper.dart';

/// Use instead of [BoxCollection] to add automatic tracing.
class SentryBoxCollection implements BoxCollection {
  final BoxCollection _boxCollection;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbHiveBoxCollection,
  );

  Hub _hub = HubAdapter();

  /// Init with [BoxCollection]
  SentryBoxCollection(this._boxCollection);

  @override
  void setHub(Hub hub) {
    _hub = hub;
    _spanHelper.setHub(hub);
  }

  @override
  // TODO: implement boxNames
  Set<String> get boxNames => _boxCollection.boxNames;

  @override
  void close() {
    _boxCollection.close();
  }

  @override
  Future<void> deleteFromDisk() async {
    return await _spanHelper.asyncWrapInSpan(
      'deleteFromDisk',
      () async {
        return await _boxCollection.deleteFromDisk();
      },
      dbName: name,
    );
  }

  @override
  String get name => _boxCollection.name;

  static Future<BoxCollection> open(
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
    if (hub != null) {
      spanHelper.setHub(hub);
    }
    return await spanHelper.asyncWrapInSpan(
      'open',
      () async {
        final boxCollection = await BoxCollection.open(
          name,
          boxNames,
          path: path,
          key: key,
        );
        return SentryBoxCollection(boxCollection);
      },
      dbName: name,
    );
  }

  @override
  Future<CollectionBox<V>> openBox<V>(
    String name, {
    bool preload = false,
    CollectionBox<V> Function(String p1, BoxCollection p2)? boxCreator,
  }) async {
    return await _spanHelper.asyncWrapInSpan(
      'openBox',
      () async {
        return await _boxCollection.openBox(
          name,
          preload: preload,
          boxCreator: boxCreator,
        );
      },
      dbName: name,
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
      () async {
        return await _boxCollection.transaction(
          action,
          boxNames: boxNames,
          readOnly: readOnly,
        );
      },
      dbName: name,
    );
  }
}
