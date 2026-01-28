import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
// ignore: implementation_imports
import 'package:sqflite_common/src/factory_mixin.dart';
// ignore: implementation_imports
import 'package:sqflite/src/sqflite_impl.dart' as impl;

import 'sentry_database.dart';
import 'utils/sentry_sqflite_span_helper.dart';

/// Using this factory, all [Database] instances will be wrapped with Sentry.
///
/// Only use the factory if you want to wrap all [Database] instances even from
/// 3rd party libraries and SDKs, otherwise prefer the [openDatabaseWithSentry]
/// or [SentryDatabase] constructor.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
///
/// databaseFactory = SentrySqfliteDatabaseFactory();
/// // or SentrySqfliteDatabaseFactory(databaseFactory: databaseFactoryFfi);
/// // if you are using the FFI or Web implementation.
///
/// final database = await openDatabase('path/to/db');
/// ```
@experimental
class SentrySqfliteDatabaseFactory with SqfliteDatabaseFactoryMixin {
  /// ```dart
  /// import 'package:sqflite/sqflite.dart';
  ///
  /// databaseFactory = SentrySqfliteDatabaseFactory();
  ///
  /// final database = await openDatabase('path/to/db');
  /// ```
  SentrySqfliteDatabaseFactory({
    sqflite.DatabaseFactory? databaseFactory,
    @internal Hub? hub,
  })  : _databaseFactory = databaseFactory ?? sqflite.databaseFactory,
        _hub = hub ?? HubAdapter();

  final Hub _hub;
  final sqflite.DatabaseFactory _databaseFactory;

  @override
  Future<T> invokeMethod<T>(String method, [Object? arguments]) =>
      impl.invokeMethod(method, arguments);

  @override
  Future<sqflite.Database> openDatabase(
    String path, {
    sqflite.OpenDatabaseOptions? options,
  }) async {
    final databaseFactory = _databaseFactory;

    // ignore: invalid_use_of_internal_member
    if (!_hub.options.isTracingEnabled()) {
      return databaseFactory.openDatabase(path, options: options);
    }

    final helper = SentrySqfliteSpanHelper(
      // ignore: invalid_use_of_internal_member
      spanWrapper: _hub.options.spanWrapper,
      hub: _hub,
    );

    return helper.wrapAsync<sqflite.Database>(
      operation: SentryDatabase.dbOp,
      description: 'Open DB: $path',
      execute: () async {
        final database =
            await databaseFactory.openDatabase(path, options: options);
        return SentryDatabase(database, hub: _hub);
      },
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseFactory,
      parentSpan: _hub.getSpan(),
    );
  }
}
