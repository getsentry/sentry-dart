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

  void verifyErrorSpan(
      String description, Exception exception, SentrySpan? span) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHiveBoxBase);
    expect(span?.data[SentryHiveImpl.dbSystemKey], SentryHiveImpl.dbSystem);
    expect(span?.data[SentryHiveImpl.dbNameKey], Fixture.dbName);

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

    test('add adds span', () async {
      final sut = fixture.getSut();

      await sut.add(Person('Joe Dirt'));

      verifySpan('add', fixture.getCreatedSpan());
    });

    test('addAll adds span', () async {
      final sut = fixture.getSut();

      await sut.addAll([Person('Joe Dirt')]);

      verifySpan('addAll', fixture.getCreatedSpan());
    });

    test('clear adds span', () async {
      final sut = fixture.getSut();

      await sut.clear();

      verifySpan('clear', fixture.getCreatedSpan());
    });

    test('close adds span', () async {
      final sut = fixture.getSut();

      await sut.close();

      verifySpan('close', fixture.getCreatedSpan());
    });

    test('compact adds span', () async {
      final sut = fixture.getSut();

      await sut.compact();

      verifySpan('compact', fixture.getCreatedSpan());
    });

    test('delete adds span', () async {
      final sut = fixture.getSut();

      await sut.delete('fixture-key');

      verifySpan('delete', fixture.getCreatedSpan());
    });

    test('deleteAll adds span', () async {
      final sut = fixture.getSut();

      await sut.deleteAll(['fixture-key']);

      verifySpan('deleteAll', fixture.getCreatedSpan());
    });

    test('deleteAt adds span', () async {
      final sut = fixture.getSut();

      await sut.add(Person('Joe Dirt'));
      await sut.deleteAt(0);

      verifySpan('deleteAt', fixture.getCreatedSpan());
    });
  });

  group('adds error span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockBock.name).thenReturn(Fixture.dbName);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('failing add adds errored span', () async {
      when(fixture.mockBock.add(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      try {
        await sut.add(Person('Joe Dirt'));
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('add', fixture.exception, fixture.getCreatedSpan());
    });

    test('failing addAll adds errored span', () async {
      when(fixture.mockBock.addAll(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      try {
        await sut.addAll([Person('Joe Dirt')]);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('addAll', fixture.exception, fixture.getCreatedSpan());
    });

    test('failing clear adds errored span', () async {
      when(fixture.mockBock.clear()).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      try {
        await sut.clear();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('clear', fixture.exception, fixture.getCreatedSpan());
    });

    test('failing close adds errored span', () async {
      when(fixture.mockBock.close()).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      try {
        await sut.close();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('close', fixture.exception, fixture.getCreatedSpan());
    });

    test('failing compact adds errored span', () async {
      when(fixture.mockBock.compact()).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      try {
        await sut.compact();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('compact', fixture.exception, fixture.getCreatedSpan());
    });

    test('failing delete adds errored span', () async {
      when(fixture.mockBock.delete(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      try {
        await sut.delete('fixture-key');
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('delete', fixture.exception, fixture.getCreatedSpan());
    });

    test('failing deleteAll adds errored span', () async {
      when(fixture.mockBock.deleteAll(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      try {
        await sut.deleteAll(['fixture-key']);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('deleteAll', fixture.exception, fixture.getCreatedSpan());
    });

    test('failing deleteAt adds errored span', () async {
      when(fixture.mockBock.add(any)).thenAnswer((_) async {
        return 1;
      });
      when(fixture.mockBock.deleteAt(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(mockBox: true);

      await sut.add(Person('Joe Dirt'));
      try {
        await sut.deleteAt(0);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('deleteAt', fixture.exception, fixture.getCreatedSpan());
    });
  });
}

class Fixture {
  late final Box<Person> box;
  late final mockBock = MockBox<Person>();
  final options = SentryOptions();
  final hub = MockHub();
  final exception = Exception('fixture-exception');

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
    await Hive.close();
  }

  SentryBoxBase<Person> getSut({bool mockBox = false}) {
    if (mockBox) {
      return SentryBoxBase(mockBock, hub);
    } else {
      return SentryBoxBase(box, hub);
    }
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
