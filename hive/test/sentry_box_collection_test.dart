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

  void verifyErrorSpan(
    String description,
    Exception exception,
    SentrySpan? span,
  ) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHiveBoxCollection);
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

  group('adds span when calling', () {
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

    test('open', () async {
      await SentryBoxCollection.open(
        Fixture.dbName,
        {'people'},
        hub: fixture.hub,
      );

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

  group('adds error span when calling', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockBoxCollection.name).thenReturn(Fixture.dbName);
      when(fixture.hub.scope).thenReturn(fixture.scope);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    // open is static and cannot be mocked

    test('throwing openBox', () async {
      when(
        // ignore: inference_failure_on_function_invocation
        fixture.mockBoxCollection.openBox(
          any,
          preload: anyNamed('preload'),
          boxCreator: anyNamed('boxCreator'),
        ),
      ).thenThrow(fixture.exception);

      final sut = await fixture.getSut(injectMock: true);

      try {
        // ignore: inference_failure_on_function_invocation
        await sut.openBox('people');
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('openBox', fixture.exception, fixture.getCreatedSpan());
    });

    test('throwing transaction', () async {
      when(
        fixture.mockBoxCollection.transaction(
          any,
          boxNames: anyNamed('boxNames'),
          readOnly: anyNamed('readOnly'),
        ),
      ).thenThrow(fixture.exception);

      final sut = await fixture.getSut(injectMock: true);

      try {
        await sut.transaction(() async {});
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan(
        'transaction',
        fixture.exception,
        fixture.getCreatedSpan(),
      );
    });

    test('throwing deleteFromDisk', () async {
      when(fixture.mockBoxCollection.deleteFromDisk())
          .thenThrow(fixture.exception);

      final sut = await fixture.getSut(injectMock: true);

      try {
        await sut.deleteFromDisk();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan(
        'deleteFromDisk',
        fixture.exception,
        fixture.getCreatedSpan(),
      );
    });
  });

  group('adds breadcrumb when calling', () {
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

    test('open', () async {
      await SentryBoxCollection.open(
        Fixture.dbName,
        {'people'},
        hub: fixture.hub,
      );

      final span = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('open', span);
    });

    test('openBox', () async {
      final sut = await fixture.getSut();

      await sut.openBox<Person>('people');

      final span = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('openBox', span);
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
      final span = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('transaction', span);
    });

    test('deleteFromDisk', () async {
      final sut = await fixture.getSut();

      await sut.deleteFromDisk();

      final span = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('deleteFromDisk', span);
    });
  });

  group('adds error breadcrumb when calling', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockBoxCollection.name).thenReturn(Fixture.dbName);
      when(fixture.hub.scope).thenReturn(fixture.scope);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    // open is static and cannot be mocked

    test('throwing openBox', () async {
      when(
        // ignore: inference_failure_on_function_invocation
        fixture.mockBoxCollection.openBox(
          any,
          preload: anyNamed('preload'),
          boxCreator: anyNamed('boxCreator'),
        ),
      ).thenThrow(fixture.exception);

      final sut = await fixture.getSut(injectMock: true);

      try {
        // ignore: inference_failure_on_function_invocation
        await sut.openBox('people');
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'openBox',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing transaction', () async {
      when(
        fixture.mockBoxCollection.transaction(
          any,
          boxNames: anyNamed('boxNames'),
          readOnly: anyNamed('readOnly'),
        ),
      ).thenThrow(fixture.exception);

      final sut = await fixture.getSut(injectMock: true);

      try {
        await sut.transaction(() async {});
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'transaction',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing deleteFromDisk', () async {
      when(fixture.mockBoxCollection.deleteFromDisk())
          .thenThrow(fixture.exception);

      final sut = await fixture.getSut(injectMock: true);

      try {
        await sut.deleteFromDisk();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'deleteFromDisk',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });
  });
}

class Fixture {
  final options = SentryOptions();
  final hub = MockHub();
  final exception = Exception('fixture-exception');

  late final mockBoxCollection = MockBoxCollection();

  static final dbName = 'people-box-collection';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late final scope = Scope(options);

  Future<void> setUp() async {
    SentryHive.init(Directory.systemTemp.path);
    if (!SentryHive.isAdapterRegistered(0)) {
      SentryHive.registerAdapter(PersonAdapter());
    }
  }

  Future<void> tearDown() async {
    await SentryHive.close();
  }

  Future<stub.BoxCollection> getSut({bool injectMock = false}) async {
    if (injectMock) {
      final sbc = SentryBoxCollection(mockBoxCollection);
      sbc.setHub(hub);
      return sbc;
    } else {
      return await SentryBoxCollection.open(dbName, {'people'}, hub: hub);
    }
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  Breadcrumb? getCreatedBreadcrumb() {
    return hub.scope.breadcrumbs.last;
  }
}
