// ignore_for_file: library_annotations

@TestOn('vm')

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_hive/src/sentry_box.dart';
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
    expect(span?.data['sync'], true);
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
    expect(span?.data['sync'], true);

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

  group('adds sync spans', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);
      when(fixture.mockBox.name).thenReturn(Fixture.dbName);

      // Mock sync methods
      when(fixture.mockBox.get(any)).thenReturn(Person('test'));
      when(fixture.mockBox.getAt(0)).thenReturn(Person('test'));
      when(fixture.mockBox.values).thenReturn([Person('test')]);
      when(fixture.mockBox.valuesBetween()).thenReturn([Person('test')]);

      await fixture.setUp(useMock: true);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('get adds sync span', () {
      fixture.getSut(injectMock: true).get('key');
      final span = fixture.getCreatedSpan();
      verifySpan('get', span);
    });

    test('getAt adds sync span', () {
      fixture.getSut(injectMock: true).getAt(0);
      final span = fixture.getCreatedSpan();
      verifySpan('getAt', span);
    });

    test('values adds sync span', () {
      fixture.getSut(injectMock: true).values;
      final span = fixture.getCreatedSpan();
      verifySpan('values', span);
    });

    test('valuesBetween adds sync span', () {
      fixture.getSut(injectMock: true).valuesBetween();
      final span = fixture.getCreatedSpan();
      verifySpan('valuesBetween', span);
    });
  });

  group('adds error sync spans', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);
      when(fixture.mockBox.name).thenReturn(Fixture.dbName);

      // Mock sync methods to throw
      when(fixture.mockBox.get(any)).thenThrow(fixture.exception);
      when(fixture.mockBox.getAt(0)).thenThrow(fixture.exception);
      when(fixture.mockBox.values).thenThrow(fixture.exception);
      when(fixture.mockBox.valuesBetween()).thenThrow(fixture.exception);

      await fixture.setUp(useMock: true);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing get adds error sync span', () {
      try {
        fixture.getSut(injectMock: true).get('key');
      } catch (error) {
        // ignore
      }
      final span = fixture.getCreatedSpan();
      verifyErrorSpan('get', fixture.exception, span);
    });

    test('throwing getAt adds error sync span', () {
      try {
        fixture.getSut(injectMock: true).getAt(0);
      } catch (error) {
        // ignore
      }
      final span = fixture.getCreatedSpan();
      verifyErrorSpan('getAt', fixture.exception, span);
    });

    test('throwing values adds error sync span', () {
      try {
        fixture.getSut(injectMock: true).values;
      } catch (error) {
        // ignore
      }
      final span = fixture.getCreatedSpan();
      verifyErrorSpan('values', fixture.exception, span);
    });

    test('throwing valuesBetween adds error sync span', () {
      try {
        fixture.getSut(injectMock: true).valuesBetween();
      } catch (error) {
        // ignore
      }
      final span = fixture.getCreatedSpan();
      verifyErrorSpan('valuesBetween', fixture.exception, span);
    });
  });

  group('adds sync breadcrumbs', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);
      when(fixture.mockBox.name).thenReturn(Fixture.dbName);

      // Mock sync methods
      when(fixture.mockBox.get(any)).thenReturn(Person('test'));
      when(fixture.mockBox.getAt(0)).thenReturn(Person('test'));
      when(fixture.mockBox.values).thenReturn([Person('test')]);
      when(fixture.mockBox.valuesBetween()).thenReturn([Person('test')]);

      await fixture.setUp(useMock: true);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('get adds sync breadcrumb', () {
      fixture.getSut(injectMock: true).get('key');
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('get', breadcrumb, checkName: true);
    });

    test('getAt adds sync breadcrumb', () {
      fixture.getSut(injectMock: true).getAt(0);
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('getAt', breadcrumb, checkName: true);
    });

    test('values adds sync breadcrumb', () {
      fixture.getSut(injectMock: true).values;
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('values', breadcrumb, checkName: true);
    });

    test('valuesBetween adds sync breadcrumb', () {
      fixture.getSut(injectMock: true).valuesBetween();
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('valuesBetween', breadcrumb, checkName: true);
    });
  });
}

class Fixture {
  late final Box<Person> box;
  late final mockBox = MockBox<Person>();
  final options = defaultTestOptions();
  final hub = MockHub();
  final exception = Exception('fixture-exception');

  static final dbName = 'people-box';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late final scope = Scope(options);

  Future<void> setUp({bool useMock = false}) async {
    if (!useMock) {
      Hive.init(Directory.systemTemp.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PersonAdapter());
      }
      box = await Hive.openBox(dbName);
    }
  }

  Future<void> tearDown() async {
    try {
      if (box.isOpen) {
        await box.deleteFromDisk();
        await box.close();
      }
      await Hive.close();
    } catch (e) {
      // Ignore errors if box was not initialized
    }
  }

  SentryBox<Person> getSut({bool injectMock = false}) {
    if (injectMock) {
      return SentryBox(mockBox, hub);
    } else {
      return SentryBox(box, hub);
    }
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  Breadcrumb? getCreatedBreadcrumb() {
    return hub.scope.breadcrumbs.last;
  }
}
