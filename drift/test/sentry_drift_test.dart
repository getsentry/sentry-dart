// ignore_for_file: invalid_use_of_internal_member, library_annotations

@TestOn('vm')

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_drift/src/constants.dart' as drift_constants;
import 'package:sentry_drift/src/sentry_query_interceptor.dart';
import 'package:sentry_drift/src/version.dart';
import 'package:sqlite3/open.dart';

import 'mocks/mocks.mocks.dart';
import 'test_database.dart';
import 'utils.dart';
import 'utils/windows_helper.dart';

void main() {
  open.overrideFor(OperatingSystem.windows, openOnWindows);

  final expectedInsertStatement =
      'INSERT INTO "todo_items" ("title", "body") VALUES (?, ?)';
  final expectedUpdateStatement =
      'UPDATE "todo_items" SET "title" = ?, "body" = ? WHERE "title" = ?;';
  final expectedSelectStatement = 'SELECT * FROM todo_items';
  final expectedDeleteStatement = 'DELETE FROM "todo_items";';

  void verifySpan(
    String description,
    SentrySpan? span, {
    String? operation,
    SpanStatus? status,
  }) {
    status ??= SpanStatus.ok();
    expect(
      span?.context.operation,
      operation ?? SentrySpanOperations.dbSqlQuery,
    );
    expect(span?.context.description, description);
    expect(span?.status, status);
    expect(span?.origin, SentryTraceOrigins.autoDbDriftQueryInterceptor);
    expect(
      span?.data[SentrySpanData.dbSystemKey],
      SentrySpanData.dbSystemSqlite,
    );
    expect(
      span?.data[SentrySpanData.dbNameKey],
      Fixture.dbName,
    );
  }

  void verifyErrorSpan(
    String description,
    Exception exception,
    SentrySpan? span, {
    String? operation,
    SpanStatus? status,
  }) {
    expect(
      span?.context.operation,
      operation ?? SentrySpanOperations.dbSqlQuery,
    );
    expect(span?.context.description, description);
    expect(span?.status, status ?? SpanStatus.internalError());
    expect(span?.origin, SentryTraceOrigins.autoDbDriftQueryInterceptor);
    expect(
      span?.data[SentrySpanData.dbSystemKey],
      SentrySpanData.dbSystemSqlite,
    );
    expect(
      span?.data[SentrySpanData.dbNameKey],
      Fixture.dbName,
    );

    expect(span?.throwable, exception);
  }

  Future<void> insertRow(AppDatabase sut, {bool withError = false}) {
    if (withError) {
      return sut.into(sut.todoItems).insert(
            TodoItemsCompanion.insert(
              title: '',
              content: '',
            ),
          );
    } else {
      return sut.into(sut.todoItems).insert(
            TodoItemsCompanion.insert(
              title: 'todo: finish drift setup',
              content: 'We can now write queries and define our own tables.',
            ),
          );
    }
  }

  Future<void> insertIntoBatch(AppDatabase sut) {
    return sut.batch((batch) {
      batch.insertAll(sut.todoItems, [
        TodoItemsCompanion.insert(
          title: 'todo: finish drift setup #1',
          content: 'We can now write queries and define our own tables.',
        ),
        TodoItemsCompanion.insert(
          title: 'todo: finish drift setup #2',
          content: 'We can now write queries and define our own tables.',
        ),
      ]);
    });
  }

  Future<void> updateRow(AppDatabase sut, {bool withError = false}) {
    if (withError) {
      return (sut.update(sut.todoItems)
            ..where((tbl) => tbl.title.equals('doesnt exist')))
          .write(
        TodoItemsCompanion(
          title: Value('after update'),
          content: Value('We can now write queries and define our own tables.'),
        ),
      );
    } else {
      return (sut.update(sut.todoItems)
            ..where((tbl) => tbl.title.equals('todo: finish drift setup')))
          .write(
        TodoItemsCompanion(
          title: Value('after update'),
          content: Value('We can now write queries and define our own tables.'),
        ),
      );
    }
  }

  SentryTracer startTransaction() {
    return Sentry.startTransaction('drift', 'test op', bindToScope: true)
        as SentryTracer;
  }

  group('open operations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await Sentry.init(
        (options) {},
        options: fixture.options,
      );
    });

    test('successful adds span only once', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await insertRow(db);
      await insertRow(db);
      await insertRow(db);

      final openSpans = tx.children.where(
        (element) =>
            element.context.description ==
            SentrySpanDescriptions.dbOpen(dbName: Fixture.dbName),
      );

      expect(openSpans.length, 1);
      verifySpan(
        operation: SentrySpanOperations.dbOpen,
        SentrySpanDescriptions.dbOpen(dbName: Fixture.dbName),
        openSpans.first,
      );
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenThrow(exception);
      when(queryExecutor.runInsert(any, any))
          .thenAnswer((_) => Future.value(1));
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = startTransaction();
      try {
        await insertRow(db);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      final openSpans = tx.children.where(
        (element) =>
            element.context.description ==
            SentrySpanDescriptions.dbOpen(dbName: Fixture.dbName),
      );

      expect(openSpans.length, 1);
      verifyErrorSpan(
        operation: SentrySpanOperations.dbOpen,
        SentrySpanDescriptions.dbOpen(dbName: Fixture.dbName),
        exception,
        openSpans.first,
      );
    });
  });

  group('close operations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await Sentry.init(
        (options) {},
        options: defaultTestOptions()..tracesSampleRate = 1.0,
      );
    });

    test('successful adds close only once', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await insertRow(db);
      await db.close();

      final closeSpans = tx.children.where(
        (element) =>
            element.context.description ==
            SentrySpanDescriptions.dbClose(dbName: Fixture.dbName),
      );

      expect(closeSpans.length, 1);
      verifySpan(
        operation: SentrySpanOperations.dbClose,
        SentrySpanDescriptions.dbClose(dbName: Fixture.dbName),
        closeSpans.first,
      );
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(queryExecutor.runInsert(any, any))
          .thenAnswer((_) => Future.value(1));
      when(queryExecutor.close()).thenThrow(exception);
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = startTransaction();
      try {
        await insertRow(db);
        await db.close();
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      final closeSpans = tx.children.where(
        (element) =>
            element.context.description ==
            SentrySpanDescriptions.dbClose(dbName: Fixture.dbName),
      );

      expect(closeSpans.length, 1);
      verifyErrorSpan(
        SentrySpanDescriptions.dbClose(dbName: Fixture.dbName),
        exception,
        closeSpans.first,
        operation: SentrySpanOperations.dbClose,
      );
    });
  });

  group('insert operations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.sentryInit();
    });

    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await insertRow(db);

      verifySpan(
        expectedInsertStatement,
        tx.children.last,
      );
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(queryExecutor.runInsert(any, any)).thenThrow(exception);
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = startTransaction();
      try {
        await insertRow(db);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      verifyErrorSpan(
        expectedInsertStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('update operations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.sentryInit();
    });

    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await insertRow(db);
      await updateRow(db);

      verifySpan(
        expectedUpdateStatement,
        tx.children.last,
      );
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(queryExecutor.runInsert(any, any))
          .thenAnswer((_) => Future.value(1));
      when(queryExecutor.runUpdate(any, any)).thenThrow(exception);
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = startTransaction();
      try {
        await insertRow(db);
        await updateRow(db);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      verifyErrorSpan(
        expectedUpdateStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('delete operations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.sentryInit();
    });

    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await insertRow(db);
      await db.delete(db.todoItems).go();

      verifySpan(
        expectedDeleteStatement,
        tx.children.last,
      );
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(queryExecutor.runInsert(any, any))
          .thenAnswer((_) => Future.value(1));
      when(queryExecutor.runDelete(any, any)).thenThrow(exception);
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = startTransaction();
      try {
        await insertRow(db);
        await db.delete(db.todoItems).go();
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      verifyErrorSpan(
        expectedDeleteStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('custom query operations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.sentryInit();
    });

    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await db.customStatement(expectedSelectStatement);

      verifySpan(
        expectedSelectStatement,
        tx.children.last,
      );
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(queryExecutor.runCustom(any, any)).thenThrow(exception);
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = startTransaction();
      try {
        await db.customStatement(expectedSelectStatement);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      verifyErrorSpan(
        expectedSelectStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('transaction operations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.sentryInit();
    });

    // already tests nesting
    test('commit successful adds spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await db.transaction(() async {
        await db.into(db.todoItems).insert(
              TodoItemsCompanion.insert(
                title: 'first transaction insert',
                content: 'test',
              ),
            );
        await db.transaction(() async {
          await db.delete(db.todoItems).go();
        });
      });

      // 5 spans = 1 db open + 2 tx + 1 insert + 1 delete
      expect(tx.children.length, 5);

      final outerTxSpan = tx.children[1];
      final insertSpan = tx.children[2];
      final innerTxSpan = tx.children[3];
      final deleteSpan = tx.children[4];

      // Verify parent relationships
      expect(outerTxSpan.context.parentSpanId, tx.context.spanId);
      expect(insertSpan.context.parentSpanId, outerTxSpan.context.spanId);
      expect(innerTxSpan.context.parentSpanId, outerTxSpan.context.spanId);
      expect(deleteSpan.context.parentSpanId, innerTxSpan.context.spanId);
    });

    test('successful commit adds insert spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await db.transaction(() async {
        await insertRow(db);
        await insertRow(db);
      });

      final insertSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedInsertStatement,
          )
          .length;
      expect(insertSpanCount, 2);

      verifySpan(
        expectedInsertStatement,
        tx.children.last,
      );

      verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds update spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await db.transaction(() async {
        await insertRow(db);
        await updateRow(db);
      });

      final insertSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedInsertStatement,
          )
          .length;
      expect(insertSpanCount, 1);

      final updateSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedInsertStatement,
          )
          .length;
      expect(updateSpanCount, 1);

      verifySpan(
        expectedUpdateStatement,
        tx.children.last,
      );

      verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds delete spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await db.transaction(() async {
        await insertRow(db);
        await db.delete(db.todoItems).go();
      });

      final insertSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedInsertStatement,
          )
          .length;
      expect(insertSpanCount, 1);

      final deleteSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedDeleteStatement,
          )
          .length;
      expect(deleteSpanCount, 1);

      verifySpan(
        expectedDeleteStatement,
        tx.children.last,
      );

      verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds custom query spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await db.transaction(() async {
        await db.customStatement(expectedSelectStatement);
      });

      final customSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedSelectStatement,
          )
          .length;
      expect(customSpanCount, 1);

      verifySpan(
        expectedSelectStatement,
        tx.children.last,
      );

      verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds batch spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await db.transaction(() async {
        await insertIntoBatch(db);
      });

      verifySpan(
        SentrySpanDescriptions.dbBatch(statements: [expectedInsertStatement]),
        tx.children.last,
        operation: SentrySpanOperations.dbSqlBatch,
      );
    });

    test('batch creates transaction span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await insertIntoBatch(db);

      verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );

      verifySpan(
        SentrySpanDescriptions.dbBatch(statements: [expectedInsertStatement]),
        tx.children.last,
        operation: SentrySpanOperations.dbSqlBatch,
      );
    });

    test('rollback case adds aborted span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      await insertRow(db);
      await insertRow(db);

      try {
        await db.transaction(() async {
          await insertRow(db, withError: true);
        });
      } catch (_) {}

      final spans =
          tx.children.where((child) => child.status == SpanStatus.aborted());
      expect(spans.length, 1);
      final abortedSpan = spans.first;

      expect(sut.spanHelper.transactionStack, isEmpty);
      verifySpan(
        SentrySpanDescriptions.dbTransaction,
        abortedSpan,
        status: SpanStatus.aborted(),
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('batch does not add span for failed operations', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = startTransaction();
      try {
        await db.batch((batch) async {
          await insertRow(db, withError: true);
          await insertRow(db);
        });
      } catch (_) {}

      expect(tx.children.isEmpty, true);
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(queryExecutor.beginTransaction()).thenThrow(exception);
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = startTransaction();
      try {
        await db.transaction(() async {
          await insertRow(db);
        });
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      // when beginTransaction errored, we don't add it to the stack
      expect(sut.spanHelper.transactionStack, isEmpty);
      verifyErrorSpan(
        operation: SentrySpanOperations.dbSqlTransaction,
        SentrySpanDescriptions.dbTransaction,
        exception,
        tx.children.last,
      );
    });
  });

  group('integrations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.sentryInit();

      // init the interceptor so the integrations are added
      fixture.getSut();
    });

    test('adds integration', () {
      expect(
        fixture.options.sdk.integrations
            .contains(drift_constants.integrationName),
        true,
      );
    });

    test('adds package', () {
      expect(
        fixture.options.sdk.packages.any(
          (element) =>
              element.name == packageName && element.version == sdkVersion,
        ),
        true,
      );
    });
  });
}

class Fixture {
  static final dbName = 'test_db_name';
  final options = defaultTestOptions()..tracesSampleRate = 1.0;

  Future<void> sentryInit() {
    return Sentry.init(
      (options) {},
      options: options,
    );
  }

  SentryQueryInterceptor getSut({Hub? hub}) {
    hub = hub ?? HubAdapter();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return SentryQueryInterceptor(databaseName: dbName, hub: hub);
  }
}
