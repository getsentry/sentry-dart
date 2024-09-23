@TestOn('vm')

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_hive/src/sentry_box.dart';
import 'package:sentry_hive/src/sentry_hive_impl.dart';
import 'package:sentry_hive/src/sentry_lazy_box.dart';
import 'package:sentry_hive/src/version.dart';
import 'package:test/test.dart';

import 'mocks/mocks.mocks.dart';
import 'person.dart';
import 'utils.dart';

void main() {
  void verifySpan(
    String description,
    SentrySpan? span, {
    bool checkName = false,
  }) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHive);
    // expect(span?.data[SentryHiveImpl.dbSystemKey], SentryHiveImpl.dbSystem);
    if (checkName) {
      expect(span?.data[SentryHiveImpl.dbNameKey], Fixture.dbName);
    }
  }

  void verifyErrorSpan(String description, SentrySpan? span, Exception error) {
    expect(span?.context.operation, SentryHiveImpl.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbHive);
    expect(span?.throwable, error);
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

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);

      await fixture.setUp();
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
      verifySpan('openBox', fixture.getCreatedSpan(), checkName: true);
    });

    test('openLazyBox adds span', () async {
      final sut = fixture.getSut();

      final box = await sut.openLazyBox<Person>(Fixture.dbName);

      expect(box is SentryLazyBox<Person>, true);
      verifySpan('openLazyBox', fixture.getCreatedSpan(), checkName: true);
    });
  });

  group('adds error span', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockHive.close()).thenAnswer((_) async => {});
      when(fixture.hub.scope).thenReturn(fixture.scope);

      await fixture.setUp(injectMockHive: true);
    });

    test('throwing boxExists adds error span', () async {
      final Box<Person> box = MockBox<Person>();
      when(
        fixture.mockHive.openBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          bytes: anyNamed('bytes'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenAnswer((_) => Future(() => box));
      when(fixture.mockHive.boxExists(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      try {
        await sut.boxExists(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('boxExists', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing close adds error span', () async {
      when(fixture.mockHive.close()).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      try {
        await sut.close();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('close', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing deleteBoxFromDisk adds error span', () async {
      final Box<Person> box = MockBox<Person>();
      when(
        fixture.mockHive.openBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          bytes: anyNamed('bytes'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenAnswer((_) => Future(() => box));
      when(fixture.mockHive.deleteBoxFromDisk(any))
          .thenThrow(fixture.exception);

      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      try {
        await sut.deleteBoxFromDisk(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan(
        'deleteBoxFromDisk',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing deleteFromDisk adds error span', () async {
      when(fixture.mockHive.deleteFromDisk()).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      try {
        await sut.deleteFromDisk();
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan(
        'deleteFromDisk',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing openBox adds error span', () async {
      when(
        fixture.mockHive.openBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          bytes: anyNamed('bytes'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      try {
        await sut.openBox<Person>(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan('openBox', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing openLazyBox adds error span', () async {
      when(
        fixture.mockHive.openLazyBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      try {
        await sut.openLazyBox<Person>(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyErrorSpan(
        'openLazyBox',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });
  });

  group('adds breadcrumbs', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);

      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('boxExists adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      await sut.boxExists(Fixture.dbName);

      verifyBreadcrumb('boxExists', fixture.getCreatedBreadcrumb());
    });

    test('close adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.close();

      verifyBreadcrumb('close', fixture.getCreatedBreadcrumb());
    });

    test('deleteBoxFromDisk adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      await sut.deleteBoxFromDisk(Fixture.dbName);

      verifyBreadcrumb('deleteBoxFromDisk', fixture.getCreatedBreadcrumb());
    });

    test('deleteFromDisk adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.deleteFromDisk();

      verifyBreadcrumb('deleteFromDisk', fixture.getCreatedBreadcrumb());
    });

    test('openBox adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);

      verifyBreadcrumb(
        'openBox',
        fixture.getCreatedBreadcrumb(),
        checkName: true,
      );
    });

    test('openLazyBox adds breadcrumb', () async {
      final sut = fixture.getSut();

      await sut.openLazyBox<Person>(Fixture.dbName);

      verifyBreadcrumb(
        'openLazyBox',
        fixture.getCreatedBreadcrumb(),
        checkName: true,
      );
    });
  });

  group('adds error breadcrumb', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.mockHive.close()).thenAnswer((_) async => {});
      when(fixture.hub.scope).thenReturn(fixture.scope);

      await fixture.setUp(injectMockHive: true);
    });

    test('throwing boxExists adds error span', () async {
      final Box<Person> box = MockBox<Person>();
      when(
        fixture.mockHive.openBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          bytes: anyNamed('bytes'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenAnswer((_) => Future(() => box));
      when(fixture.mockHive.boxExists(any)).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      try {
        await sut.boxExists(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'boxExists',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing close adds error span', () async {
      when(fixture.mockHive.close()).thenThrow(fixture.exception);

      final sut = fixture.getSut();

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

    test('throwing deleteBoxFromDisk adds error span', () async {
      final Box<Person> box = MockBox<Person>();
      when(
        fixture.mockHive.openBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          bytes: anyNamed('bytes'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenAnswer((_) => Future(() => box));
      when(fixture.mockHive.deleteBoxFromDisk(any))
          .thenThrow(fixture.exception);

      final sut = fixture.getSut();

      await sut.openBox<Person>(Fixture.dbName);
      try {
        await sut.deleteBoxFromDisk(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'deleteBoxFromDisk',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing deleteFromDisk adds error span', () async {
      when(fixture.mockHive.deleteFromDisk()).thenThrow(fixture.exception);

      final sut = fixture.getSut();

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

    test('throwing openBox adds error span', () async {
      when(
        fixture.mockHive.openBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          bytes: anyNamed('bytes'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      try {
        await sut.openBox<Person>(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'openBox',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing openLazyBox adds error span', () async {
      when(
        fixture.mockHive.openLazyBox<Person>(
          any,
          encryptionCipher: anyNamed('encryptionCipher'),
          keyComparator: anyNamed('keyComparator'),
          compactionStrategy: anyNamed('compactionStrategy'),
          crashRecovery: anyNamed('crashRecovery'),
          path: anyNamed('path'),
          collection: anyNamed('collection'),
          encryptionKey: anyNamed('encryptionKey'),
        ),
      ).thenThrow(fixture.exception);

      final sut = fixture.getSut();

      try {
        await sut.openLazyBox<Person>(Fixture.dbName);
      } catch (error) {
        expect(error, fixture.exception);
      }

      verifyBreadcrumb(
        'openLazyBox',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });
  });

  group('integrations', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);

      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('adds integration', () {
      expect(
        fixture.options.sdk.integrations.contains('SentryHiveTracing'),
        true,
      );
    });

    test('adds package', () {
      expect(
        fixture.options.sdk.packages.any(
          (element) =>
              element.name == packageName && element.version == sdkVersion,
        ),
        true,
      );
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  late final mockHive = MockHiveInterface();
  final hub = MockHub();
  static final dbName = 'people-hive-impl';
  final exception = Exception('fixture-exception');

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late SentryHiveImpl sut;
  late final scope = Scope(options);

  Future<void> setUp({bool injectMockHive = false}) async {
    if (injectMockHive) {
      sut = SentryHiveImpl(mockHive);
    } else {
      sut = SentryHiveImpl(Hive);
      sut.init(Directory.systemTemp.path);
      if (!sut.isAdapterRegistered(0)) {
        sut.registerAdapter(PersonAdapter());
      }
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

  Breadcrumb? getCreatedBreadcrumb() {
    return hub.scope.breadcrumbs.last;
  }
}
