// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_drift/src/sentry_query_executor.dart';
import 'package:sentry_drift/src/sentry_transaction_executor.dart';
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
  final expectedCloseStatement = 'Close DB: ${Fixture.dbName}';
  final expectedOpenStatement = 'Open DB: ${Fixture.dbName}';
  final expectedTransactionStatement = 'transaction';
  final withinTransactionDescription = 'Within transaction: ';

  void verifySpan(
    String description,
    SentrySpan? span, {
    String origin = SentryTraceOrigins.autoDbDriftQueryExecutor,
    SpanStatus? status,
  }) {
    status ??= SpanStatus.ok();
    expect(span?.context.operation, SentryQueryExecutor.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, status);
    expect(span?.origin, origin);
    expect(
      span?.data[SentryQueryExecutor.dbSystemKey],
      SentryQueryExecutor.dbSystem,
    );
    expect(
      span?.data[SentryQueryExecutor.dbNameKey],
      Fixture.dbName,
    );
  }

  void verifyErrorSpan(
    String description,
    Exception exception,
    SentrySpan? span, {
    String origin = SentryTraceOrigins.autoDbDriftQueryExecutor,
  }) {
    expect(span?.context.operation, SentryQueryExecutor.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    expect(span?.origin, origin);
    expect(
      span?.data[SentryQueryExecutor.dbSystemKey],
      SentryQueryExecutor.dbSystem,
    );
    expect(
      span?.data[SentryQueryExecutor.dbNameKey],
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
            (element) => element.context.description == expectedOpenStatement,
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
            (element) =>
                element.context.description ==
                '$withinTransactionDescription$expectedInsertStatement',
          )
          .length;
      expect(insertSpanCount, 2);

      verifySpan(
        '$withinTransactionDescription$expectedInsertStatement',
        fixture.getCreatedSpan(),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
      );

      verifySpan(
        expectedTransactionStatement,
        fixture.getCreatedSpanByDescription(expectedTransactionStatement),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
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
            (element) =>
                element.context.description ==
                '$withinTransactionDescription$expectedUpdateStatement',
          )
          .length;
      expect(updateSpanCount, 1);

      verifySpan(
        '$withinTransactionDescription$expectedUpdateStatement',
        fixture.getCreatedSpan(),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
      );

      verifySpan(
        expectedTransactionStatement,
        fixture.getCreatedSpanByDescription(expectedTransactionStatement),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
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
            (element) =>
                element.context.description ==
                '$withinTransactionDescription$expectedDeleteStatement',
          )
          .length;
      expect(deleteSpanCount, 1);

      verifySpan(
        '$withinTransactionDescription$expectedDeleteStatement',
        fixture.getCreatedSpan(),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
      );

      verifySpan(
        expectedTransactionStatement,
        fixture.getCreatedSpanByDescription(expectedTransactionStatement),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
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
            (element) =>
                element.context.description ==
                '$withinTransactionDescription$expectedSelectStatement',
          )
          .length;
      expect(customSpanCount, 1);

      verifySpan(
        '$withinTransactionDescription$expectedSelectStatement',
        fixture.getCreatedSpan(),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
      );

      verifySpan(
        expectedTransactionStatement,
        fixture.getCreatedSpanByDescription(expectedTransactionStatement),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
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
        expectedTransactionStatement,
        abortedSpan,
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
        status: SpanStatus.aborted(),
      );
    });

    test('batch adds span', () async {
      final sut = fixture.sut;

      await sut.batch((batch) async {
        await insertRow(sut);
        await insertRow(sut);
      });

      verifySpan(
        'batch',
        fixture.getCreatedSpan(),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
      );
    });

    test('close adds span', () async {
      final sut = fixture.sut;

      await sut.close();

      verifySpan(
        'Close DB: ${Fixture.dbName}',
        fixture.getCreatedSpan(),
      );
    });

    test('open adds span', () async {
      final sut = fixture.sut;

      // SentryDriftDatabase is by default lazily opened by default so it won't
      // create a span until it is actually used.
      await sut.select(sut.todoItems).get();

      verifySpan(
        expectedOpenStatement,
        fixture.getCreatedSpanByDescription(expectedOpenStatement),
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

      await fixture.setUp(injectMock: true);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing runInsert throws error span', () async {
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
      when(fixture.mockLazyDatabase.runUpdate(any, any))
          .thenThrow(fixture.exception);

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

      try {
        // We need to move it inside the try/catch becaue SentryTransactionExecutor
        // starts beginTransaction() directly after init
        final SentryTransactionExecutor transactionExecutor =
            SentryTransactionExecutor(
          mockTransactionExecutor,
          fixture.hub,
          dbName: Fixture.dbName,
        );

        when(fixture.mockLazyDatabase.beginTransaction())
            .thenReturn(transactionExecutor);

        await fixture.sut.transaction(() async {
          await insertRow(fixture.sut);
        });
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedTransactionStatement,
        fixture.exception,
        fixture.getCreatedSpan(),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
      );
    });

    test('throwing batch throws error span', () async {
      final mockTransactionExecutor = MockTransactionExecutor();
      when(mockTransactionExecutor.beginTransaction())
          .thenThrow(fixture.exception);

      // We need to move it inside the try/catch becaue SentryTransactionExecutor
      // starts beginTransaction() directly after init
      final SentryTransactionExecutor transactionExecutor =
          SentryTransactionExecutor(
        mockTransactionExecutor,
        fixture.hub,
        dbName: Fixture.dbName,
      );

      when(fixture.mockLazyDatabase.beginTransaction())
          .thenReturn(transactionExecutor);

      when(fixture.mockLazyDatabase.runInsert(any, any))
          .thenAnswer((realInvocation) => Future.value(1));

      try {
        await fixture.sut.batch((batch) async {
          await insertRow(fixture.sut);
        });
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedTransactionStatement,
        fixture.exception,
        fixture.getCreatedSpan(),
        origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
      );
    });

    test('throwing close throws error span', () async {
      when(fixture.mockLazyDatabase.close()).thenThrow(fixture.exception);
      when(fixture.mockLazyDatabase.runInsert(any, any))
          .thenAnswer((_) => Future.value(1));

      try {
        await insertRow(fixture.sut);
        await fixture.sut.close();
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedCloseStatement,
        fixture.exception,
        fixture.getCreatedSpan(),
      );

      when(fixture.mockLazyDatabase.close()).thenAnswer((_) => Future.value());
    });

    test('throwing ensureOpen throws error span', () async {
      when(fixture.mockLazyDatabase.ensureOpen(any))
          .thenThrow(fixture.exception);

      try {
        await fixture.sut.select(fixture.sut.todoItems).get();
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
        expectedOpenStatement,
        fixture.exception,
        fixture.getCreatedSpanByDescription(expectedOpenStatement),
      );
    });

    test('throwing runDelete throws error span', () async {
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
        fixture.options.sdk.integrations.contains('SentryDriftTracing'),
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

  Future<void> setUp({bool injectMock = false}) async {
    sut = AppDatabase(openConnection(injectMock: injectMock));
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

  SentryQueryExecutor openConnection({bool injectMock = false}) {
    if (injectMock) {
      final executor =
          SentryQueryExecutor(() => mockLazyDatabase, databaseName: dbName);
      executor.setHub(hub);
      return executor;
    } else {
      return SentryQueryExecutor(
        () {
          return NativeDatabase.memory();
        },
        hub: hub,
        databaseName: dbName,
      );
    }
  }
}
