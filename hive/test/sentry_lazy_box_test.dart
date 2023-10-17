@TestOn('vm')

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_hive/src/sentry_hive_impl.dart';
import 'package:sentry_hive/src/sentry_lazy_box.dart';
import 'package:test/test.dart';

import 'mocks/mocks.mocks.dart';
import 'person.dart';

void main() {
  void verifySpan(String description, SentrySpan? span) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHiveLazyBox);
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

    test('get adds span', () async {
      final sut = fixture.getSut();

      await sut.put('fixture-key', Person('John Malkovich'));
      await sut.get('fixture-key');

      verifySpan('get', fixture.getCreatedSpan());
    });

    test('getAt adds span', () async {
      final sut = fixture.getSut();

      await sut.add(Person('John Malkovich'));
      await sut.getAt(0);

      verifySpan('getAt', fixture.getCreatedSpan());
    });
  });
}

class Fixture {
  late final LazyBox<Person> box;
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
    box = await Hive.openLazyBox(dbName);
  }

  Future<void> tearDown() async {
    if (box.isOpen) {
      await box.deleteFromDisk();
      await box.close();
    }
    await Hive.close();
  }

  SentryLazyBox<Person> getSut() {
    return SentryLazyBox(box, hub);
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
