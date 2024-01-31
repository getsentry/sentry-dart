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

  void verifyErrorSpan(
    String description,
    Exception exception,
    SentrySpan? span,
  ) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHiveLazyBox);
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

    test('throwing get adds error span', () async {
      when(fixture.mockBox.add(any)).thenAnswer((_) async {
        return 1;
      });
      when(fixture.mockBox.get(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      await sut.put('fixture-key', Person('John Malkovich'));
      try {
        await sut.get('fixture-key');
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('get', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing getAt adds error span', () async {
      when(fixture.mockBox.add(any)).thenAnswer((_) async {
        return 1;
      });
      when(fixture.mockBox.getAt(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      await sut.add(Person('John Malkovich'));
      try {
        await sut.getAt(0);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('getAt', fixture.exception, fixture.getCreatedSpan());
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

    test('get adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.put('fixture-key', Person('John Malkovich'));
      await sut.get('fixture-key');

      verifyBreadcrumb('get', fixture.getCreatedBreadcrumb());
    });

    test('getAt adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.add(Person('John Malkovich'));
      await sut.getAt(0);

      verifyBreadcrumb('getAt', fixture.getCreatedBreadcrumb());
    });
  });

  group('adds error breadcrumbs', () {
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

    test('throwing get adds error breadcrumbs', () async {
      when(fixture.mockBox.add(any)).thenAnswer((_) async {
        return 1;
      });
      when(fixture.mockBox.get(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      await sut.put('fixture-key', Person('John Malkovich'));
      try {
        await sut.get('fixture-key');
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'get',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing getAt adds error breadcrumbs', () async {
      when(fixture.mockBox.add(any)).thenAnswer((_) async {
        return 1;
      });
      when(fixture.mockBox.getAt(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut(injectMockBox: true);

      await sut.add(Person('John Malkovich'));
      try {
        await sut.getAt(0);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'getAt',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });
  });
}

class Fixture {
  late final LazyBox<Person> box;
  late final mockBox = MockLazyBox<Person>();
  final options = SentryOptions();
  final hub = MockHub();
  final exception = Exception('fixture-exception');

  static final dbName = 'people-lazy-box';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late final scope = Scope(options);

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

  SentryLazyBox<Person> getSut({bool injectMockBox = false}) {
    if (injectMockBox) {
      return SentryLazyBox(mockBox, hub);
    } else {
      return SentryLazyBox(box, hub);
    }
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  Breadcrumb? getCreatedBreadcrumb() {
    return hub.scope.breadcrumbs.last;
  }
}
