// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_drift/src/sentry_query_executor.dart';
import 'package:sentry_drift/src/sentry_transaction_executor.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'mocks/mocks.mocks.dart';
import 'test_database.dart';

void main() {
  void verifySpan(String description, SentrySpan? span,
      {String origin = SentryTraceOrigins.autoDbDriftQueryExecutor,
      SpanStatus? status,}) {
    status ??= SpanStatus.ok();
    expect(span?.context.operation, SentryQueryExecutor.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, status);
    expect(span?.origin, origin);
    expect(span?.data[SentryQueryExecutor.dbSystemKey],
        SentryQueryExecutor.dbSystem,);
    expect(span?.data[SentryQueryExecutor.dbNameKey], Fixture.dbName,);
  }

  void verifyErrorSpan(
      String description, Exception exception, SentrySpan? span,
      {String origin = SentryTraceOrigins.autoDbDriftQueryExecutor,}) {
    expect(span?.context.operation, SentryQueryExecutor.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    expect(span?.origin, origin);
    expect(span?.data[SentryQueryExecutor.dbSystemKey],
        SentryQueryExecutor.dbSystem,);
    expect(span?.data[SentryQueryExecutor.dbNameKey], Fixture.dbName,);

    expect(span?.throwable, exception);
  }

  Future<void> insertRow(AppDatabase sut, {bool withError = false}) {
    if (withError) {
      return sut.into(sut.todoItems).insert(TodoItemsCompanion.insert(
            title: '',
            content: '',
          ),);
    } else {
      return sut.into(sut.todoItems).insert(TodoItemsCompanion.insert(
            title: 'todo: finish drift setup',
            content: 'We can now write queries and define our own tables.',
          ),);
    }
  }

  Future<void> updateRow(AppDatabase sut, {bool withError = false}) {
    if (withError) {
      return (sut.update(sut.todoItems)
            ..where((tbl) => tbl.title.equals('doesnt exist')))
          .write(TodoItemsCompanion(
        title: Value('after update'),
        content: Value('We can now write queries and define our own tables.'),
      ),);
    } else {
      return (sut.update(sut.todoItems)
            ..where((tbl) => tbl.title.equals('todo: finish drift setup')))
          .write(TodoItemsCompanion(
        title: Value('after update'),
        content: Value('We can now write queries and define our own tables.'),
      ),);
    }
  }

  group('adds span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('insert adds span', () async {
      final sut = fixture.sut;

      await insertRow(sut);

      verifySpan('insert', fixture.getCreatedSpan());
    });

    test('update adds span', () async {
      final sut = fixture.sut;

      await insertRow(sut);
      await updateRow(sut);

      verifySpan('update', fixture.getCreatedSpan());
    });

    test('custom adds span', () async {
      final sut = fixture.sut;

      await sut.customStatement('SELECT * FROM todo_items');

      verifySpan('custom', fixture.getCreatedSpan());
    });

    test('transaction adds span', () async {
      final sut = fixture.sut;

      await sut.transaction(() async {
        await insertRow(sut);
      });

      verifySpan('transaction', fixture.getCreatedSpan(),
          origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,);
    });

    test('transaction rollback adds span', () async {
      final sut = fixture.sut;

      try {
        await sut.transaction(() async {
          await insertRow(sut, withError: true);
        });
      } catch (_) {}

      verifySpan('transaction', fixture.getCreatedSpan(),
          origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,
          status: SpanStatus.aborted(),);
    });

    test('batch adds span', () async {
      final sut = fixture.sut;

      await sut.batch((batch) async {
        await insertRow(sut);
        await insertRow(sut);
      });

      verifySpan('batch', fixture.getCreatedSpan(),
          origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,);
    });

    test('close adds span', () async {
      final sut = fixture.sut;

      await sut.close();

      verifySpan('close', fixture.getCreatedSpan());
    });

    test('open adds span', () async {
      final sut = fixture.sut;

      // SentryDriftDatabase is by default lazily opened by default so it won't
      // create a span until it is actually used.
      await sut.select(sut.todoItems).get();

      verifySpan('open', fixture.getCreatedSpanByDescription('open'));
    });
  });

  group('does not add span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
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

    test('batch does not add span for failed operations', () async {
      final lazyDatabase = MockLazyDatabase();
      final queryExecutor =
          SentryQueryExecutor(() => lazyDatabase, databaseName: Fixture.dbName,);
      queryExecutor.setHub(fixture.hub);
      when(lazyDatabase.ensureOpen(any)).thenAnswer((_) => Future.value(true));
      when(lazyDatabase.runInsert(any, any)).thenThrow(fixture.exception);
      final sut = AppDatabase(queryExecutor);

      try {
        await insertRow(sut);
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan('insert', fixture.exception, fixture.getCreatedSpan());
    });
  });

  group('adds error span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp(injectMock: true);

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockLazyDatabase.ensureOpen(any))
          .thenAnswer((_) => Future.value(true));
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

      verifyErrorSpan('insert', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing runUpdate throws error span', () async {
      when(fixture.mockLazyDatabase.runUpdate(any, any))
          .thenThrow(fixture.exception);

      try {
        await updateRow(fixture.sut);
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan('update', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing runCustom throws error span', () async {
      when(fixture.mockLazyDatabase.runCustom(any, any))
          .thenThrow(fixture.exception);

      try {
        await fixture.sut.customStatement('SELECT * FROM todo_items');
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan('custom', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing transaction throws error span', () async {
      final mockTransactionExecutor = MockTransactionExecutor();
      when(mockTransactionExecutor.beginTransaction())
          .thenThrow(fixture.exception);

      try {
        // We need to move it inside the try/catch becaue SentryTransactionExecutor
        // starts beginTransaction() directly after init
        final SentryTransactionExecutor transactionExecutor =
            SentryTransactionExecutor(mockTransactionExecutor, fixture.hub,
                dbName: Fixture.dbName,);

        when(fixture.mockLazyDatabase.beginTransaction())
            .thenReturn(transactionExecutor);

        await fixture.sut.transaction(() async {
          await insertRow(fixture.sut);
        });
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
          'transaction', fixture.exception, fixture.getCreatedSpan(),
          origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,);
    });

    test('throwing batch throws error span', () async {
      final mockTransactionExecutor = MockTransactionExecutor();
      when(mockTransactionExecutor.beginTransaction())
          .thenThrow(fixture.exception);

      try {
        // We need to move it inside the try/catch becaue SentryTransactionExecutor
        // starts beginTransaction() directly after init
        final SentryTransactionExecutor transactionExecutor =
            SentryTransactionExecutor(mockTransactionExecutor, fixture.hub,
                dbName: Fixture.dbName,);

        when(fixture.mockLazyDatabase.beginTransaction())
            .thenReturn(transactionExecutor);

        await fixture.sut.batch((batch) async {
          await insertRow(fixture.sut);
        });
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan(
          'transaction', fixture.exception, fixture.getCreatedSpan(),
          origin: SentryTraceOrigins.autoDbDriftTransactionExecutor,);
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

      verifyErrorSpan('close', fixture.exception, fixture.getCreatedSpan());

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

      verifyErrorSpan('open', fixture.exception,
          fixture.getCreatedSpanByDescription('open'),);
    });

    test('throwing runDelete throws error span', () async {
      when(fixture.mockLazyDatabase.runDelete(any, any))
          .thenThrow(fixture.exception);

      try {
        await fixture.sut.delete(fixture.sut.todoItems).go();
      } catch (exception) {
        expect(exception, fixture.exception);
      }

      verifyErrorSpan('delete', fixture.exception, fixture.getCreatedSpan());
    });
  });
}

class Fixture {
  final options = SentryOptions();
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
      return SentryQueryExecutor(() {
        return NativeDatabase.memory();
      }, hub: hub, databaseName: dbName,);
    }
  }
}
