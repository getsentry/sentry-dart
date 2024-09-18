import 'package:isar/isar.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'version.dart';

import 'sentry_isar_collection.dart';
import 'sentry_span_helper.dart';

/// A sentry wrapper around the Isar Database
@experimental
class SentryIsar implements Isar {
  @internal
  // ignore: public_member_api_docs
  static const dbOp = 'db';

  @internal
  // ignore: public_member_api_docs
  static const dbSystemKey = 'db.system';
  @internal
  // ignore: public_member_api_docs
  static const dbSystem = 'isar';

  @internal
  // ignore: public_member_api_docs
  static const dbNameKey = 'db.name';

  @internal
  // ignore: public_member_api_docs
  static const dbCollectionKey = 'db.collection';

  final Isar _isar;
  final Hub _hub;
  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbIsar,
  );

  /// ctor of SentryIsar
  SentryIsar(this._isar, this._hub) {
    _spanHelper.setHub(_hub);

    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    options.sdk.addIntegration('SentryIsarTracing');
    options.sdk.addPackage(packageName, sdkVersion);
  }

  /// Open a new Isar instance, wrapped by SentryIsar
  static Future<Isar> open(
    List<CollectionSchema<dynamic>> schemas, {
    required String directory,
    String name = Isar.defaultName,
    int maxSizeMiB = Isar.defaultMaxSizeMiB,
    bool relaxedDurability = true,
    CompactCondition? compactOnLaunch,
    bool inspector = true,
    Hub? hub,
  }) async {
    final spanHelper = SentrySpanHelper(
      // ignore: invalid_use_of_internal_member
      SentryTraceOrigins.autoDbIsar,
    );
    final hubToUse = hub ?? HubAdapter();
    spanHelper.setHub(hubToUse);

    final isar = await spanHelper.asyncWrapInSpan(
      'open',
      () async {
        return await Isar.open(
          schemas,
          directory: directory,
          name: name,
          maxSizeMiB: maxSizeMiB,
          relaxedDurability: relaxedDurability,
          compactOnLaunch: compactOnLaunch,
          inspector: inspector,
        );
      },
      dbName: name,
    );

    return SentryIsar(isar, hubToUse);
  }

  /// Open a new Isar instance, wrapped by SentryIsar
  static Isar openSync(
    List<CollectionSchema<dynamic>> schemas, {
    required String directory,
    String name = Isar.defaultName,
    int maxSizeMiB = Isar.defaultMaxSizeMiB,
    bool relaxedDurability = true,
    CompactCondition? compactOnLaunch,
    bool inspector = true,
    Hub? hub,
  }) {
    final isar = Isar.openSync(
      schemas,
      directory: directory,
      name: name,
      maxSizeMiB: maxSizeMiB,
      relaxedDurability: relaxedDurability,
      compactOnLaunch: compactOnLaunch,
      inspector: inspector,
    );
    return SentryIsar(isar, hub ?? HubAdapter());
  }

  @override
  void attachCollections(Map<Type, IsarCollection<dynamic>> collections) {
    _isar.attachCollections(collections);
  }

  @override
  Future<void> clear() {
    return _spanHelper.asyncWrapInSpan(
      'clear',
      () {
        return _isar.clear();
      },
      dbName: name,
    );
  }

  @override
  void clearSync() {
    _isar.clearSync();
  }

  @override
  Future<bool> close({bool deleteFromDisk = false}) {
    return _spanHelper.asyncWrapInSpan(
      'close',
      () {
        return _isar.close(deleteFromDisk: deleteFromDisk);
      },
      dbName: name,
    );
  }

  @override
  IsarCollection<T> collection<T>() {
    return SentryIsarCollection(_isar.collection(), _hub, name);
  }

  @override
  Future<void> copyToFile(String targetPath) {
    return _spanHelper.asyncWrapInSpan(
      'copyToFile',
      () {
        return _isar.copyToFile(targetPath);
      },
      dbName: name,
    );
  }

  @override
  String? get directory => _isar.directory;

  @override
  IsarCollection<dynamic>? getCollectionByNameInternal(String name) {
    final collection = _isar.getCollectionByNameInternal(name);
    if (collection != null) {
      return SentryIsarCollection(collection, _hub, name);
    } else {
      return null;
    }
  }

  @override
  Future<int> getSize({
    bool includeIndexes = false,
    bool includeLinks = false,
  }) {
    return _spanHelper.asyncWrapInSpan(
      'getSize',
      () {
        return _isar.getSize(
          includeIndexes: includeIndexes,
          includeLinks: includeLinks,
        );
      },
      dbName: name,
    );
  }

  @override
  int getSizeSync({bool includeIndexes = false, bool includeLinks = false}) {
    return _isar.getSizeSync(
      includeIndexes: includeIndexes,
      includeLinks: includeLinks,
    );
  }

  @override
  bool get isOpen => _isar.isOpen;

  @override
  String get name => _isar.name;

  @override
  String? get path => _isar.path;

  @override
  void requireOpen() {
    _isar.requireOpen();
  }

  @override
  Future<T> txn<T>(Future<T> Function() callback) {
    return _spanHelper.asyncWrapInSpan(
      'txn',
      () {
        return _isar.txn(callback);
      },
      dbName: name,
    );
  }

  @override
  T txnSync<T>(T Function() callback) {
    return _isar.txnSync(callback);
  }

  @override
  @visibleForTesting
  @experimental
  Future<void> verify() {
    return _spanHelper.asyncWrapInSpan(
      'verify',
      () {
        // ignore: invalid_use_of_visible_for_testing_member
        return _isar.verify();
      },
      dbName: name,
    );
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false}) {
    return _spanHelper.asyncWrapInSpan(
      'writeTxn',
      () {
        return _isar.writeTxn(callback, silent: silent);
      },
      dbName: name,
    );
  }

  @override
  T writeTxnSync<T>(T Function() callback, {bool silent = false}) {
    return _isar.writeTxnSync(callback, silent: silent);
  }
}
