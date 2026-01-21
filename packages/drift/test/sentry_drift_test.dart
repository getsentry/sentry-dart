// ignore_for_file: invalid_use_of_internal_member, library_annotations

@TestOn('vm')

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
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
  final expectedSelectStatement = 'SELECT * FROM "todo_items";';
  final expectedDeleteStatement = 'DELETE FROM "todo_items";';

  late Fixture fixture;

  setUp(() async {
    fixture = Fixture();
    await Sentry.init(
      (options) {},
      options: fixture.options,
    );
  });

  group('open operations', () {
    test('successful adds span only once', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);
      await _insertRow(db);
      await _insertRow(db);

      final openSpans = tx.children.where(
        (element) =>
            element.context.description ==
            SentrySpanDescriptions.dbOpen(dbName: Fixture.dbName),
      );

      expect(openSpans.length, 1);
      _verifySpan(
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

      final tx = _startTransaction();
      try {
        await _insertRow(db);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      final openSpans = tx.children.where(
        (element) =>
            element.context.description ==
            SentrySpanDescriptions.dbOpen(dbName: Fixture.dbName),
      );

      expect(openSpans.length, 1);
      _verifyErrorSpan(
        operation: SentrySpanOperations.dbOpen,
        SentrySpanDescriptions.dbOpen(dbName: Fixture.dbName),
        exception,
        openSpans.first,
      );
    });
  });

  group('close operations', () {
    test('successful adds close only once', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);
      await db.close();

      final closeSpans = tx.children.where(
        (element) =>
            element.context.description ==
            SentrySpanDescriptions.dbClose(dbName: Fixture.dbName),
      );

      expect(closeSpans.length, 1);
      _verifySpan(
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

      final tx = _startTransaction();
      try {
        await _insertRow(db);
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
      _verifyErrorSpan(
        SentrySpanDescriptions.dbClose(dbName: Fixture.dbName),
        exception,
        closeSpans.first,
        operation: SentrySpanOperations.dbClose,
      );
    });
  });

  group('insert operations', () {
    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);

      _verifySpan(
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

      final tx = _startTransaction();
      try {
        await _insertRow(db);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      _verifyErrorSpan(
        expectedInsertStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('update operations', () {
    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);
      await _updateRow(db);

      _verifySpan(
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

      final tx = _startTransaction();
      try {
        await _insertRow(db);
        await _updateRow(db);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      _verifyErrorSpan(
        expectedUpdateStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('delete operations', () {
    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);
      await db.delete(db.todoItems).go();

      _verifySpan(
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

      final tx = _startTransaction();
      try {
        await _insertRow(db);
        await db.delete(db.todoItems).go();
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      _verifyErrorSpan(
        expectedDeleteStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('select operations', () {
    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);
      await db.select(db.todoItems).get();

      _verifySpan(
        expectedSelectStatement,
        tx.children.last,
      );
    });

    test('error case adds error span', () async {
      final exception = Exception('test');
      final queryExecutor = MockQueryExecutor();
      when(queryExecutor.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(queryExecutor.runInsert(any, any))
          .thenAnswer((_) => Future.value(1));
      when(queryExecutor.runSelect(any, any)).thenThrow(exception);
      when(queryExecutor.dialect).thenReturn(SqlDialect.sqlite);

      final sut = fixture.getSut();
      final db = AppDatabase(queryExecutor.interceptWith(sut));

      final tx = _startTransaction();
      try {
        await _insertRow(db);
        await db.select(db.todoItems).get();
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      _verifyErrorSpan(
        expectedSelectStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('custom query operations', () {
    test('successful adds span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await db.customStatement(expectedSelectStatement);

      _verifySpan(
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

      final tx = _startTransaction();
      try {
        await db.customStatement(expectedSelectStatement);
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      _verifyErrorSpan(
        expectedSelectStatement,
        exception,
        tx.children.last,
      );
    });
  });

  group('transaction operations', () {
    test('without transaction, spans are added to active scope span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);

      expect(tx.children.length, 2);

      final insertSpan = tx.children.last;
      expect(insertSpan.context.parentSpanId, tx.context.spanId);
      expect(sut.transactionStack, isEmpty);
    });

    // already tests nesting
    test('commit successful adds spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
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

      final tx = _startTransaction();
      await db.transaction(() async {
        await _insertRow(db);
        await _insertRow(db);
      });

      final insertSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedInsertStatement,
          )
          .length;
      expect(insertSpanCount, 2);

      _verifySpan(
        expectedInsertStatement,
        tx.children.last,
      );

      _verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds update spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await db.transaction(() async {
        await _insertRow(db);
        await _updateRow(db);
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

      _verifySpan(
        expectedUpdateStatement,
        tx.children.last,
      );

      _verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds delete spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await db.transaction(() async {
        await _insertRow(db);
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

      _verifySpan(
        expectedDeleteStatement,
        tx.children.last,
      );

      _verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds custom query spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await db.transaction(() async {
        await db.customStatement(expectedSelectStatement);
      });

      final customSpanCount = tx.children
          .where(
            (element) => element.context.description == expectedSelectStatement,
          )
          .length;
      expect(customSpanCount, 1);

      _verifySpan(
        expectedSelectStatement,
        tx.children.last,
      );

      _verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test('successful commit adds batch spans', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await db.transaction(() async {
        await _insertIntoBatch(db);
      });

      _verifySpan(
        SentrySpanDescriptions.dbBatch(statements: [expectedInsertStatement]),
        tx.children.last,
        operation: SentrySpanOperations.dbSqlBatch,
      );
    });

    test('batch creates transaction span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertIntoBatch(db);

      _verifySpan(
        SentrySpanDescriptions.dbTransaction,
        tx.children[1],
        operation: SentrySpanOperations.dbSqlTransaction,
      );

      _verifySpan(
        SentrySpanDescriptions.dbBatch(statements: [expectedInsertStatement]),
        tx.children.last,
        operation: SentrySpanOperations.dbSqlBatch,
      );
    });

    test('rollback case adds aborted span', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      await _insertRow(db);
      await _insertRow(db);

      try {
        await db.transaction(() async {
          await _insertRow(db, withError: true);
        });
      } catch (_) {}

      final spans =
          tx.children.where((child) => child.status == SpanStatus.aborted());
      expect(spans.length, 1);
      final abortedSpan = spans.first;

      expect(sut.transactionStack, isEmpty);
      _verifySpan(
        SentrySpanDescriptions.dbTransaction,
        abortedSpan,
        status: SpanStatus.aborted(),
        operation: SentrySpanOperations.dbSqlTransaction,
      );
    });

    test(
        'transaction is rolled back within Sentry transaction, added aborted span',
        () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();

      // pre-condition: table empty
      expect(await db.select(db.todoItems).get(), isEmpty);

      // run a transaction that is forced to fail -> should be rolled back
      await expectLater(
        () => db.transaction(() async {
          await _insertRow(db, withError: true);
        }),
        throwsA(isA<Exception>()),
      );

      final abortedSpans =
          tx.children.where((child) => child.status == SpanStatus.aborted());
      expect(abortedSpans.length, 1);

      // if rollback happened the row must be absent
      expect(await db.select(db.todoItems).get(), isEmpty);
    });

    test('transaction is rolled back without Sentry transaction', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      // pre-condition: table empty
      expect(await db.select(db.todoItems).get(), isEmpty);

      // run a transaction that is forced to fail -> should be rolled back
      await expectLater(
        () => db.transaction(() async {
          await _insertRow(db, withError: true);
        }),
        throwsA(isA<Exception>()),
      );

      // if rollback happened the row must be absent
      expect(await db.select(db.todoItems).get(), isEmpty);
    });

    test('batch does not add span for failed operations', () async {
      final sut = fixture.getSut();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(sut));

      final tx = _startTransaction();
      try {
        await db.batch((batch) async {
          await _insertRow(db, withError: true);
          await _insertRow(db);
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

      final tx = _startTransaction();
      try {
        await db.transaction(() async {
          await _insertRow(db);
        });
      } catch (e) {
        // making sure the thrown exception doesn't fail the test
      }

      // when beginTransaction errored, we don't add it to the stack
      expect(sut.transactionStack, isEmpty);
      _verifyErrorSpan(
        operation: SentrySpanOperations.dbSqlTransaction,
        SentrySpanDescriptions.dbTransaction,
        exception,
        tx.children.last,
      );
    });
  });

  group('integrations', () {
    setUp(() async {
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

  SentryQueryInterceptor getSut() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return SentryQueryInterceptor(databaseName: dbName);
  }
}

void _verifySpan(
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

void _verifyErrorSpan(
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

Future<void> _insertRow(AppDatabase db, {bool withError = false}) {
  if (withError) {
    return db.into(db.todoItems).insert(
          TodoItemsCompanion.insert(
            title: '',
            content: '',
          ),
        );
  } else {
    return db.into(db.todoItems).insert(
          TodoItemsCompanion.insert(
            title: 'todo: finish drift setup',
            content: 'We can now write queries and define our own tables.',
          ),
        );
  }
}

Future<void> _insertIntoBatch(AppDatabase sut) {
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

Future<void> _updateRow(AppDatabase sut, {bool withError = false}) {
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

SentryTracer _startTransaction() {
  return Sentry.startTransaction('drift', 'test op', bindToScope: true)
      as SentryTracer;
}
