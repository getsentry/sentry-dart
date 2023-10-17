@TestOn('vm')

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_hive/src/sentry_box.dart';
import 'package:sentry_hive/src/sentry_hive_impl.dart';
import 'package:test/test.dart';

import 'mocks/mocks.mocks.dart';
import 'person.dart';

void main() {
  void verifySpan(String description, SentrySpan? span) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHive);
    // expect(span?.data[SentryHiveImpl.dbSystemKey], SentryHiveImpl.dbSystem);
    // expect(span?.data[SentryHiveImpl.dbNameKey], Fixture.dbName);
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

    test('boxExists adds span', () async {
      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      await sut.boxExists(Fixture.dbName);

      verifySpan('boxExists', fixture.getCreatedSpan());
    });

    test('close adds span', () async {
      final sut = fixture.getSut();

      await sut.close();

      verifySpan('close', fixture.getCreatedSpan());
    });

    test('deleteBoxFromDisk adds span', () async {
      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      await sut.deleteBoxFromDisk(Fixture.dbName);

      verifySpan('deleteBoxFromDisk', fixture.getCreatedSpan());
    });

    test('deleteFromDisk adds span', () async {
      final sut = fixture.getSut();

      await sut.deleteFromDisk();

      verifySpan('deleteFromDisk', fixture.getCreatedSpan());
    });

    test('openBox adds span', () async {
      final sut = fixture.getSut();

      final box = await sut.openBox<Person>(Fixture.dbName);

      expect(box is SentryBox<Person>, true);
      verifySpan('openBox', fixture.getCreatedSpan());
    });

    test('openLazyBox adds span', () async {
      final sut = fixture.getSut();

      final box = await sut.openBox<Person>(Fixture.dbName);

      expect(box is SentryBox<Person>, true);
      verifySpan('openBox', fixture.getCreatedSpan());
    });
  });
}

class Fixture {
  final options = SentryOptions();
  final hub = MockHub();
  static final dbName = 'people';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late SentryHiveImpl sut;

  Future<void> setUp() async {
    sut = SentryHiveImpl(Hive);
    sut.init(Directory.systemTemp.path);
    if (!sut.isAdapterRegistered(0)) {
      sut.registerAdapter(PersonAdapter());
    }
    sut.setHub(hub);
  }

  Future<void> tearDown() async {
    await sut.close();
  }

  SentryHiveImpl getSut() {
    return sut;
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
