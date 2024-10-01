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
import 'utils.dart';

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
    String description,
    Exception exception,
    SentrySpan? span,
  ) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHiveBoxBase);
    expect(span?.data[SentryHiveImpl.dbSystemKey], SentryHiveImpl.dbSystem);
    expect(span?.data[SentryHiveImpl.dbNameKey], Fixture.dbName);

    expect(span?.throwable, exception);
  }

  void verifyBreadcrumb(
    String message,
    Breadcrumb? crumb, {
    bool checkName = false,
    String status = 'ok',
  }) {
    expect(
      crumb?.message,
      message,
    );
    expect(crumb?.type, 'query');
    if (checkName) {
      expect(crumb?.data?[SentryHiveImpl.dbNameKey], Fixture.dbName);
    }
    expect(crumb?.data?['status'], status);
  }

  group('adds span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);
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
      when(fixture.mockBox.name).thenReturn(Fixture.dbName);
      when(fixture.hub.scope).thenReturn(fixture.scope);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing add adds error span', () async {
      when(fixture.mockBox.add(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.add(Person('Joe Dirt'));
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('add', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing addAll adds error span', () async {
      when(fixture.mockBox.addAll(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.addAll([Person('Joe Dirt')]);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('addAll', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing clear adds error span', () async {
      when(fixture.mockBox.clear()).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.clear();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('clear', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing close adds error span', () async {
      when(fixture.mockBox.close()).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.close();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('close', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing compact adds error span', () async {
      when(fixture.mockBox.compact()).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.compact();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('compact', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing delete adds error span', () async {
      when(fixture.mockBox.delete(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.delete('fixture-key');
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('delete', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing deleteAll adds error span', () async {
      when(fixture.mockBox.deleteAll(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.deleteAll(['fixture-key']);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('deleteAll', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing deleteAt adds error span', () async {
      when(fixture.mockBox.add(any)).thenAnswer((_) async {
        return 1;
      });
      when(fixture.mockBox.deleteAt(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      await sut.add(Person('Joe Dirt'));
      try {
        await sut.deleteAt(0);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('deleteAt', fixture.exception, fixture.getCreatedSpan());
    });
  });

  group('adds breadcrumb', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('add adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.add(Person('Joe Dirt'));

      verifyBreadcrumb('add', fixture.getCreatedBreadcrumb());
    });

    test('addAll adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.addAll([Person('Joe Dirt')]);

      verifyBreadcrumb('addAll', fixture.getCreatedBreadcrumb());
    });

    test('clear adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.clear();

      verifyBreadcrumb('clear', fixture.getCreatedBreadcrumb());
    });

    test('close adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.close();

      verifyBreadcrumb('close', fixture.getCreatedBreadcrumb());
    });

    test('compact adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.compact();

      verifyBreadcrumb('compact', fixture.getCreatedBreadcrumb());
    });

    test('delete adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.delete('fixture-key');

      verifyBreadcrumb('delete', fixture.getCreatedBreadcrumb());
    });

    test('deleteAll adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.deleteAll(['fixture-key']);

      verifyBreadcrumb('deleteAll', fixture.getCreatedBreadcrumb());
    });

    test('deleteAt adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.add(Person('Joe Dirt'));
      await sut.deleteAt(0);

      verifyBreadcrumb('deleteAt', fixture.getCreatedBreadcrumb());
    });
  });

  group('adds error breadcrumb', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockBox.name).thenReturn(Fixture.dbName);
      when(fixture.hub.scope).thenReturn(fixture.scope);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing add adds error breadcrumb', () async {
      when(fixture.mockBox.add(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.add(Person('Joe Dirt'));
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'add',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing addAll adds error breadcrumb', () async {
      when(fixture.mockBox.addAll(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.addAll([Person('Joe Dirt')]);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'addAll',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing clear adds error breadcrumb', () async {
      when(fixture.mockBox.clear()).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.clear();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'clear',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing close adds error breadcrumb', () async {
      when(fixture.mockBox.close()).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.close();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'close',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing compact adds error breadcrumb', () async {
      when(fixture.mockBox.compact()).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.compact();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'compact',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing delete adds error breadcrumb', () async {
      when(fixture.mockBox.delete(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.delete('fixture-key');
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'delete',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing deleteAll adds error breadcrumb', () async {
      when(fixture.mockBox.deleteAll(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      try {
        await sut.deleteAll(['fixture-key']);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'deleteAll',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing deleteAt adds error breadcrumb', () async {
      when(fixture.mockBox.add(any)).thenAnswer((_) async {
        return 1;
      });
      when(fixture.mockBox.deleteAt(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      await sut.add(Person('Joe Dirt'));
      try {
        await sut.deleteAt(0);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'deleteAt',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });
  });
}

class Fixture {
  late final Box<Person> box;
  late final mockBox = MockBox<Person>();
  final options = defaultTestOptions();
  final hub = MockHub();
  final exception = Exception('fixture-exception');

  static final dbName = 'people-box-base';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late final scope = Scope(options);

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

  SentryBoxBase<Person> getSut({bool injectMockBox = false}) {
    if (injectMockBox) {
      return SentryBoxBase(mockBox, hub);
    } else {
      return SentryBoxBase(box, hub);
    }
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  Breadcrumb? getCreatedBreadcrumb() {
    return hub.scope.breadcrumbs.last;
  }
}
