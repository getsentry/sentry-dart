import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
// ignore: implementation_imports
import 'package:sqflite_common/src/factory_mixin.dart';
// ignore: implementation_imports
import 'package:sqflite/src/sqflite_impl.dart' as impl;

import 'sentry_database.dart';

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
        _hub = hub ?? HubAdapter() {
    // ignore: invalid_use_of_internal_member
    _spanFactory = _hub.options.spanFactory;
  }

  final Hub _hub;
  final sqflite.DatabaseFactory _databaseFactory;

  // ignore: invalid_use_of_internal_member
  late final InstrumentationSpanFactory _spanFactory;

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

    return Future<sqflite.Database>(() async {
      final description = 'Open DB: $path';
      final parent = _spanFactory.getSpan(_hub);
      final span = parent != null
          ? _spanFactory.createSpan(
              parentSpan: parent,
              operation: SentryDatabase.dbOp,
              description: description,
            )
          : null;

      span?.origin =
          // ignore: invalid_use_of_internal_member
          SentryTraceOrigins.autoDbSqfliteDatabaseFactory;

      final breadcrumb = Breadcrumb(
        message: description,
        category: SentryDatabase.dbOp,
        data: {},
      );

      try {
        final database =
            await databaseFactory.openDatabase(path, options: options);

        final sentryDatabase = SentryDatabase(database, hub: _hub);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return sentryDatabase;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;
        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }
}
