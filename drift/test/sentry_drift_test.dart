// ignore_for_file: invalid_use_of_internal_member, library_annotations

@TestOn('vm')

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_drift/sentry_drift.dart';
import 'package:sentry_drift/src/constants.dart' as constants;
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
    expect(span?.context.operation, operation ?? constants.dbSqlQueryOp);
    expect(span?.context.description, description);
    expect(span?.status, status);
    expect(span?.origin, SentryTraceOrigins.autoDbDriftQueryInterceptor);
    expect(
      span?.data[constants.dbSystemKey],
      constants.dbSystem,
    );
    expect(
      span?.data[constants.dbNameKey],
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
    expect(span?.context.operation, operation ?? constants.dbSqlQueryOp);
    expect(span?.context.description, description);
    expect(span?.status, status ?? SpanStatus.internalError());
    expect(span?.origin, SentryTraceOrigins.autoDbDriftQueryInterceptor);
    expect(
      span?.data[constants.dbSystemKey],
      constants.dbSystem,
    );
    expect(
      span?.data[constants.dbNameKey],
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

  group('adds span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('open span is only added once', () async {
      final sut = fixture.sut;

      await insertRow(sut);
      await insertRow(sut);
      await insertRow(sut);

      final openSpansCount = fixture.tracer.children
          .where(
            (element) =>
                element.context.description ==
                constants.dbOpenDesc(dbName: Fixture.dbName),
          )
          .length;

      expect(openSpansCount, 1);
    });

    test('insert adds span', () async {
      final sut = fixture.sut;

      await insertRow(sut);

      verifySpan(
        expectedInsertStatement,
        fixture.getCreatedSpan(),
      );
    });

    test('update adds span', () async {
      final sut = fixture.sut;

      await insertRow(sut);
      await updateRow(sut);

      verifySpan(
        expectedUpdateStatement,
        fixture.getCreatedSpan(),
      );
    });

    test('custom adds span', () async {
      final sut = fixture.sut;

      await sut.customStatement('SELECT * FROM todo_items');

      verifySpan(
        expectedSelectStatement,
        fixture.getCreatedSpan(),
      );
    });

    test('delete adds span', () async {
      final sut = fixture.sut;

      await insertRow(sut);
      await fixture.sut.delete(fixture.sut.todoItems).go();

      verifySpan(
        expectedDeleteStatement,
        fixture.getCreatedSpan(),
      );
    });

    test('transaction adds insert spans', () async {
      final sut = fixture.sut;

      await sut.transaction(() async {
        await insertRow(sut);
        await insertRow(sut);
      });

      final insertSpanCount = fixture.tracer.children
          .where(
            (element) => element.context.description == expectedInsertStatement,
          )
          .length;
      expect(insertSpanCount, 2);

      verifySpan(
        expectedInsertStatement,
        fixture.getCreatedSpan(),
      );

      verifySpan(
        constants.dbTransactionDesc,
        fixture.getCreatedSpanByDescription(constants.dbTransactionDesc),
        operation: constants.dbSqlTransactionOp,
      );
    });

    test('transaction adds update spans', () async {
      final sut = fixture.sut;

      await sut.transaction(() async {
        await insertRow(sut);
        await updateRow(sut);
      });

      final updateSpanCount = fixture.tracer.children
          .where(
            (element) => element.context.description == expectedUpdateStatement,
          )
          .length;
      expect(updateSpanCount, 1);

      verifySpan(
        expectedUpdateStatement,
        fixture.getCreatedSpan(),
      );

      verifySpan(
        constants.dbTransactionDesc,
        fixture.getCreatedSpanByDescription(constants.dbTransactionDesc),
        operation: constants.dbSqlTransactionOp,
      );
    });

    test('transaction adds delete spans', () async {
      final sut = fixture.sut;

      await sut.transaction(() async {
        await insertRow(sut);
        await fixture.sut.delete(fixture.sut.todoItems).go();
      });

      final deleteSpanCount = fixture.tracer.children
          .where(
            (element) => element.context.description == expectedDeleteStatement,
          )
          .length;
      expect(deleteSpanCount, 1);

      verifySpan(
        expectedDeleteStatement,
        fixture.getCreatedSpan(),
      );

      verifySpan(
        constants.dbTransactionDesc,
        fixture.getCreatedSpanByDescription(constants.dbTransactionDesc),
        operation: constants.dbSqlTransactionOp,
      );
    });

    test('transaction adds custom spans', () async {
      final sut = fixture.sut;

      await sut.transaction(() async {
        await insertRow(sut);
        await sut.customStatement('SELECT * FROM todo_items');
      });

      final customSpanCount = fixture.tracer.children
          .where(
            (element) => element.context.description == expectedSelectStatement,
          )
          .length;
      expect(customSpanCount, 1);

      verifySpan(
        expectedSelectStatement,
        fixture.getCreatedSpan(),
      );

      verifySpan(
        constants.dbTransactionDesc,
        fixture.getCreatedSpanByDescription(constants.dbTransactionDesc),
        operation: constants.dbSqlTransactionOp,
      );
    });

    test('transaction rollback adds span', () async {
      final sut = fixture.sut;

      await insertRow(sut);
      await insertRow(sut);

      try {
        await sut.transaction(() async {
          await insertRow(sut, withError: true);
        });
      } catch (_) {}

      final spans = fixture.tracer.children
          .where((child) => child.status == SpanStatus.aborted());
      expect(spans.length, 1);
      final abortedSpan = spans.first;

      verifySpan(
        constants.dbTransactionDesc,
        abortedSpan,
        status: SpanStatus.aborted(),
        operation: constants.dbSqlTransactionOp,
      );
    });

    test('batch adds span', () async {
      final sut = fixture.sut;

      await insertIntoBatch(sut);

      verifySpan(
        constants.dbBatchDesc,
        fixture.getCreatedSpan(),
        operation: constants.dbSqlBatchOp,
      );
    });

    test('close adds span', () async {
      final sut = fixture.sut;

      await sut.close();

      verifySpan(
        constants.dbCloseDesc(dbName: Fixture.dbName),
        fixture.getCreatedSpan(),
        operation: constants.dbCloseOp,
      );
    });

    test('open adds span', () async {
      final sut = fixture.sut;

      // SentryDriftDatabase is by default lazily opened by default so it won't
      // create a span until it is actually used.
      await sut.select(sut.todoItems).get();

      verifySpan(
        constants.dbOpenDesc(dbName: Fixture.dbName),
        fixture.getCreatedSpanByDescription(
          constants.dbOpenDesc(dbName: Fixture.dbName),
        ),
        operation: constants.dbOpenOp,
      );
    });
  });

  group('does not add span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('does not add open span if db is not used', () async {
      fixture.sut;

      expect(fixture.tracer.children.isEmpty, true);
    });

    test('batch does not add span for failed operations', () async {
      final sut = fixture.sut;

      try {
        await sut.batch((batch) async {
          await insertRow(sut, withError: true);
          await insertRow(sut);
        });
      } catch (_) {}

      expect(fixture.tracer.children.isEmpty, true);
    });
  });

  group('adds error span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockLazyDatabase.ensureOpen(any))
          .thenAnswer((_) => Future.value(true));
      when(fixture.mockLazyDatabase.dialect).thenReturn(SqlDialect.sqlite);
    });

    tearDown(() async {
      // catch errors because we purposefully throw a close in one of the tests
      try {
        await fixture.tearDown();
      } catch (_) {}
    });

    test('throwing runInsert throws error span', () async {
      await fixture.setUp(injectMock: true);

      when(fixture.mockLazyDatabase.runInsert(any, any))
          .thenThrow(fixture.exception);

      try {
        await insertRow(fixture.sut);
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedInsertStatement,
        fixture.exception,
        fixture.getCreatedSpan(),
      );
    });

    test('throwing runUpdate throws error span', () async {
      await fixture.setUp(injectMock: true);

      when(fixture.mockLazyDatabase.runUpdate(any, any))
          .thenThrow(fixture.exception);
      when(fixture.mockLazyDatabase.ensureOpen(any))
          .thenAnswer((_) => Future.value(true));

      try {
        await updateRow(fixture.sut);
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedUpdateStatement,
        fixture.exception,
        fixture.getCreatedSpan(),
      );
    });

    test('throwing runCustom throws error span', () async {
      await fixture.setUp(injectMock: true);

      when(fixture.mockLazyDatabase.runCustom(any, any))
          .thenThrow(fixture.exception);

      try {
        await fixture.sut.customStatement('SELECT * FROM todo_items');
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedSelectStatement,
        fixture.exception,
        fixture.getCreatedSpan(),
      );
    });

    test('throwing transaction throws error span', () async {
      final mockTransactionExecutor = MockTransactionExecutor();
      when(mockTransactionExecutor.beginTransaction())
          .thenThrow(fixture.exception);
      when(mockTransactionExecutor.ensureOpen(any))
          .thenAnswer((_) => Future.value(true));

      await fixture.setUp(customExecutor: mockTransactionExecutor);

      try {
        await fixture.sut.transaction(() async {
          await insertRow(fixture.sut);
        });
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(constants.dbTransactionDesc, fixture.exception,
          fixture.getCreatedSpan(),
          operation: constants.dbSqlTransactionOp);
    });

    test('throwing batch throws error span in transaction', () async {
      await fixture.setUp(injectMock: true);

      final mockTransactionExecutor = MockTransactionExecutor();
      when(mockTransactionExecutor.ensureOpen(any))
          .thenAnswer((_) => Future.value(true));
      when(fixture.mockLazyDatabase.beginTransaction())
          .thenReturn(mockTransactionExecutor);
      when(mockTransactionExecutor.runBatched(any))
          .thenThrow(fixture.exception);

      await expectLater(
        () async => await insertIntoBatch(fixture.sut),
        throwsException,
      );

      // errored batch
      verifyErrorSpan(
        constants.dbBatchDesc,
        fixture.exception,
        fixture.getCreatedSpanByDescription(constants.dbBatchDesc),
        operation: constants.dbSqlBatchOp,
      );

      // aborted transaction
      verifySpan(
        constants.dbTransactionDesc,
        fixture.getCreatedSpanByDescription(constants.dbTransactionDesc),
        operation: constants.dbSqlTransactionOp,
        status: SpanStatus.aborted(),
      );
    });

    test('throwing close throws error span', () async {
      when(fixture.mockLazyDatabase.close()).thenThrow(fixture.exception);
      when(fixture.mockLazyDatabase.runInsert(any, any))
          .thenAnswer((_) => Future.value(1));

      await fixture.setUp(injectMock: true);

      try {
        await insertRow(fixture.sut);
        await fixture.sut.close();
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        constants.dbCloseDesc(dbName: Fixture.dbName),
        fixture.exception,
        fixture.getCreatedSpanByDescription(
            constants.dbCloseDesc(dbName: Fixture.dbName)),
        operation: constants.dbCloseOp,
      );
    });

    test('throwing ensureOpen throws error span', () async {
      await fixture.setUp(injectMock: true);

      when(fixture.mockLazyDatabase.ensureOpen(any))
          .thenThrow(fixture.exception);

      try {
        await fixture.sut.select(fixture.sut.todoItems).get();
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        constants.dbOpenDesc(dbName: Fixture.dbName),
        fixture.exception,
        fixture.getCreatedSpanByDescription(
            constants.dbOpenDesc(dbName: Fixture.dbName)),
        operation: constants.dbOpenOp,
      );
    });

    test('throwing runDelete throws error span', () async {
      await fixture.setUp(injectMock: true);

      when(fixture.mockLazyDatabase.runDelete(any, any))
          .thenThrow(fixture.exception);

      try {
        await fixture.sut.delete(fixture.sut.todoItems).go();
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedDeleteStatement,
        fixture.exception,
        fixture.getCreatedSpan(),
      );
    });
  });

  group('integrations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('adds integration', () {
      expect(
        fixture.options.sdk.integrations.contains(constants.integrationName),
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
  final options = defaultTestOptions();
  final hub = MockHub();
  static final dbName = 'people-drift-impl';
  final exception = Exception('fixture-exception');
  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late AppDatabase sut;
  final mockLazyDatabase = MockLazyDatabase();

  Future<void> setUp({
    bool injectMock = false,
    QueryExecutor? customExecutor,
  }) async {
    sut = AppDatabase(
      openConnection(injectMock: injectMock, customExecutor: customExecutor),
    );
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  Future<void> tearDown() async {
    await sut.close();
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  SentrySpan? getCreatedSpanByDescription(String description) {
    return tracer.children
        .firstWhere((element) => element.context.description == description);
  }

  QueryExecutor openConnection({
    bool injectMock = false,
    QueryExecutor? customExecutor,
  }) {
    if (customExecutor != null) {
      return customExecutor.interceptWith(
        SentryQueryInterceptor(databaseName: dbName, hub: hub),
      );
    } else if (injectMock) {
      return mockLazyDatabase.interceptWith(
        SentryQueryInterceptor(databaseName: dbName, hub: hub),
      );
    } else {
      return NativeDatabase.memory().interceptWith(
        SentryQueryInterceptor(databaseName: dbName, hub: hub),
      );
    }
  }
}
