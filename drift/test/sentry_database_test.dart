@TestOn('vm')
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_drift/src/sentry_drift_database.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'mocks/mocks.mocks.dart';
import 'test_database.dart';

void main() {
  void verifySpan(String description, SentrySpan? span) {
    expect(span?.context.operation, SentryDriftDatabase.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbDriftDatabaseExecutor);
    expect(span?.data[SentryDriftDatabase.dbSystemKey],
        SentryDriftDatabase.dbSystem);
    expect(span?.data[SentryDriftDatabase.dbNameKey], Fixture.dbName);
  }

  void verifyErrorSpan(String description,
      Exception exception,
      SentrySpan? span,) {
    expect(span?.context.operation, SentryDriftDatabase.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbDriftDatabaseExecutor);
    expect(span?.data[SentryDriftDatabase.dbSystemKey],
        SentryDriftDatabase.dbSystem);
    expect(span?.data[SentryDriftDatabase.dbNameKey], Fixture.dbName);

    expect(span?.throwable, exception);
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

      await sut.into(sut.todoItems).insert(TodoItemsCompanion.insert(
        title: 'todo: finish drift setup',
        content: 'We can now write queries and define our own tables.',
      ));

      verifySpan('insert', fixture.getCreatedSpan());
    });

    test('update adds span', () async {
      final sut = fixture.sut;

      await sut.into(sut.todoItems).insert(TodoItemsCompanion.insert(
        title: 'todo: finish drift setup',
        content: 'We can now write queries and define our own tables.',
      ));

      await (sut.update(sut.todoItems)
        ..where((tbl) => tbl.title.equals('todo: finish drift setup')))
          .write(TodoItemsCompanion(
        title: Value('after update'),
        content: Value('We can now write queries and define our own tables.'),
      ));

      verifySpan('update', fixture.getCreatedSpan());
    });

    test('custom adds span', () async {
      final sut = fixture.sut;

      await sut.customStatement('SELECT * FROM todo_items');

      verifySpan('custom', fixture.getCreatedSpan());
    });

    test('batch adds span', () async {
      final sut = fixture.sut;

      await sut.transaction(() async {
        await sut.into(sut.todoItems).insert(TodoItemsCompanion.insert(
          title: 'todo: finish drift setup',
          content: 'We can now write queries and define our own tables.',
        ));
      });

      await sut.batch((batch) async {
        await sut.into(sut.todoItems).insert(TodoItemsCompanion.insert(
          title: 'todo: finish drift setup',
          content: 'We can now write queries and define our own tables.',
        ));
      });

      // TODO
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

      verifySpan('open', fixture.getSpanByDescription('open'));
    });

    test('will not add open span if db is not used', () async {
      fixture.sut;

      expect(fixture.tracer.children.isEmpty, true);
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

  Future<void> setUp() async {
    sut = AppDatabase(openConnection());
  }

  Future<void> tearDown() async {
    await sut.close();
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  SentrySpan? getSpanByDescription(String description) {
    return tracer.children
        .firstWhere((element) => element.context.description == description);
  }

  SentryDriftDatabase openConnection() {
    return SentryDriftDatabase(() {
      return NativeDatabase.memory();
    }, hub: hub, dbName: dbName);
  }
}
