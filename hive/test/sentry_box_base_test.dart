@TestOn('vm')

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_hive/src/sentry_box_base.dart';
import 'package:sentry_hive/src/sentry_hive_impl.dart';
import 'package:test/test.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'mocks/mocks.mocks.dart';
import 'person.dart';

void main() {

  void verifySpan(String description, SentrySpan? span) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHiveBoxBase);
    expect(span?.data[SentryHiveImpl.dbSystemKey], SentryHiveImpl.dbSystem);
    expect(span?.data[SentryHiveImpl.dbNameKey], Fixture.dbName);
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

    test('add adds span', () async {
      final sut = await fixture.getSut();

      await sut.add(Person('Joe Dirt'));

      verifySpan('add', fixture.getCreatedSpan());
    });

    test('addAll adds span', () async {
      final sut = await fixture.getSut();

      await sut.addAll([Person('Joe Dirt')]);

      verifySpan('addAll', fixture.getCreatedSpan());
    });

    test('clear adds span', () async {
      final sut = await fixture.getSut();

      await sut.clear();

      verifySpan('clear', fixture.getCreatedSpan());
    });

    test('close adds span', () async {
      final sut = await fixture.getSut();

      await sut.close();

      verifySpan('close', fixture.getCreatedSpan());
    });

    test('compact adds span', () async {
      final sut = await fixture.getSut();

      await sut.compact();

      verifySpan('compact', fixture.getCreatedSpan());
    });

    test('delete adds span', () async {
      final sut = await fixture.getSut();

      await sut.delete('fixture-key');

      verifySpan('delete', fixture.getCreatedSpan());
    });

    test('deleteAll adds span', () async {
      final sut = await fixture.getSut();

      await sut.deleteAll(['fixture-key']);

      verifySpan('deleteAll', fixture.getCreatedSpan());
    });

    test('deleteAt adds span', () async {
      final sut = await fixture.getSut();

      await sut.add(Person('Joe Dirt'));
      await sut.deleteAt(0);

      verifySpan('deleteAt', fixture.getCreatedSpan());
    });
  });
}



class Fixture {
  late final Box<Person> box;
  final options = SentryOptions();
  final hub = MockHub();
  static final dbName = 'people';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);

  Future<void> setUp() async {
    Hive.init(Directory.systemTemp.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PersonAdapter());
    }
    box = await Hive.openBox(dbName);
  }

  Future<void> tearDown() async {
    if (box.isOpen) {
      await box.deleteFromDisk();
      await box.close();
    }
  }

  Future<SentryBoxBase<Person>> getSut() async {
    return SentryBoxBase(box, hub);
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
