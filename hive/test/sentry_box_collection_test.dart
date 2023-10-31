@TestOn('vm')

import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:sentry_hive/src/sentry_box_collection.dart';
import 'package:sentry_hive/src/sentry_hive_impl.dart';
import 'package:test/test.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'mocks/mocks.mocks.dart';
import 'person.dart';

import 'package:hive/src/box_collection/box_collection_stub.dart' as stub;

void main() {
  void verifySpan(String description, SentrySpan? span) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHiveBoxCollection);
    expect(span?.data[SentryHiveImpl.dbSystemKey], SentryHiveImpl.dbSystem);
    expect(span?.data[SentryHiveImpl.dbNameKey], Fixture.dbName);
  }

  group('adds span when calling', () {
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

    test('open', () async {
      await SentryBoxCollection.open(Fixture.dbName, {'people'},
          hub: fixture.hub,);

      final span = fixture.getCreatedSpan();
      verifySpan('open', span);
    });

    test('openBox', () async {
      final sut = await fixture.getSut();

      await sut.openBox<Person>('people');

      final span = fixture.getCreatedSpan();
      verifySpan('openBox', span);
    });

    test('transaction', () async {
      final sut = await fixture.getSut();

      final people = await sut.openBox<Person>('people');
      await sut.transaction(
        () async {
          print(people.name);
        },
        boxNames: ['people'],
      );
      final span = fixture.getCreatedSpan();
      verifySpan('transaction', span);
    });

    test('deleteFromDisk', () async {
      final sut = await fixture.getSut();

      await sut.deleteFromDisk();

      final span = fixture.getCreatedSpan();
      verifySpan('deleteFromDisk', span);
    });
  });
}

class Fixture {
  final options = SentryOptions();
  final hub = MockHub();
  final exception = Exception('fixture-exception');

  static final dbName = 'people-box-collection';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);

  Future<void> setUp() async {
    SentryHive.init(Directory.systemTemp.path);
    if (!SentryHive.isAdapterRegistered(0)) {
      SentryHive.registerAdapter(PersonAdapter());
    }
  }

  Future<void> tearDown() async {
    await SentryHive.close();
  }

  Future<stub.BoxCollection> getSut() async {
    return await SentryBoxCollection.open(dbName, {'people'}, hub: hub);
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
