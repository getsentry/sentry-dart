@TestOn('vm')

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_isar/src/sentry_isar.dart';

import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_isar/src/version.dart';

import 'mocks/mocks.mocks.dart';
import 'person.dart';

void main() {
  void verifySpan(String description, SentrySpan? span) {
    expect(span?.context.operation, SentryIsar.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbIsar);
    expect(span?.data[SentryIsar.dbNameKey], Fixture.dbName);
  }

  void verifyErrorSpan(String description, SentrySpan? span, Exception error) {
    expect(span?.context.operation, SentryIsar.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbIsar);
    expect(span?.throwable, error);
  }

  void verifyBreadcrumb(
    String message,
    Breadcrumb? crumb, {
    String status = 'ok',
  }) {
    expect(
      crumb?.message,
      message,
    );
    expect(crumb?.type, 'query');
    expect(crumb?.data?[SentryIsar.dbNameKey], Fixture.dbName);
    expect(crumb?.data?['status'], status);
    if (status != 'ok') {
      expect(crumb?.level, SentryLevel.warning);
    }
  }

  group('add spans', () {
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

    test('open adds span', () async {
      final span = fixture.getCreatedSpan();
      verifySpan('open', span);
    });

    test('clear adds span', () async {
      await fixture.sut.writeTxn(() async {
        await fixture.sut.clear();
      });
      final span = fixture.getCreatedSpan();
      verifySpan('clear', span);
    });

    test('close adds span', () async {
      await fixture.sut.close();
      final span = fixture.getCreatedSpan();
      verifySpan('close', span);
    });

    test('copyToFile adds span', () async {
      await fixture.sut.copyToFile(fixture.copyPath);
      final span = fixture.getCreatedSpan();
      verifySpan('copyToFile', span);
    });

    test('getSize adds span', () async {
      await fixture.sut.getSize();
      final span = fixture.getCreatedSpan();
      verifySpan('getSize', span);
    });

    test('txn adds span', () async {
      await fixture.sut.txn(() async {});
      final span = fixture.getCreatedSpan();
      verifySpan('txn', span);
    });

    test('writeTxn adds span', () async {
      await fixture.sut.writeTxn(() async {});
      final span = fixture.getCreatedSpan();
      verifySpan('writeTxn', span);
    });
  });

  group('add error spans', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);

      when(fixture.isar.close()).thenAnswer((_) async {
        return true;
      });
      when(fixture.isar.name).thenReturn(Fixture.dbName);

      await fixture.setUp(injectMock: true);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing close adds error span', () async {
      when(fixture.isar.close()).thenThrow(fixture.exception);
      try {
        await fixture.sut.close();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('close', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing clear adds error span', () async {
      when(fixture.isar.clear()).thenThrow(fixture.exception);
      try {
        await fixture.sut.clear();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('clear', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing copyToFile adds error span', () async {
      when(fixture.isar.copyToFile(any)).thenThrow(fixture.exception);
      try {
        await fixture.sut.copyToFile(fixture.copyPath);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'copyToFile',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing getSize adds error span', () async {
      when(fixture.isar.getSize()).thenThrow(fixture.exception);
      try {
        await fixture.sut.getSize();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('getSize', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing txn adds error span', () async {
      param() async {}
      when(fixture.isar.txn(param)).thenThrow(fixture.exception);
      try {
        await fixture.sut.txn(param);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('txn', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing writeTxn adds error span', () async {
      param() async {}
      when(fixture.isar.writeTxn(param)).thenThrow(fixture.exception);
      try {
        await fixture.sut.writeTxn(param);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('writeTxn', fixture.getCreatedSpan(), fixture.exception);
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

    test('open adds breadcrumb', () async {
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('open', breadcrumb);
    });

    test('clear adds breadcrumb', () async {
      await fixture.sut.writeTxn(() async {
        await fixture.sut.clear();
      });

      // order: open, clear, writeTxn

      final openCrumb = fixture.hub.scope.breadcrumbs[0];
      verifyBreadcrumb('open', openCrumb);

      final clearCrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('clear', clearCrumb);

      final writeTxnCrumb = fixture.hub.scope.breadcrumbs[2];
      verifyBreadcrumb('writeTxn', writeTxnCrumb);
    });

    test('close adds breadcrumb', () async {
      await fixture.sut.close();
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('close', breadcrumb);
    });

    test('copyToFile adds breadcrumb', () async {
      await fixture.sut.copyToFile(fixture.copyPath);
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('copyToFile', breadcrumb);
    });

    test('getSize adds breadcrumb', () async {
      await fixture.sut.getSize();
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('getSize', breadcrumb);
    });

    test('txn adds breadcrumb', () async {
      await fixture.sut.txn(() async {});
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('txn', breadcrumb);
    });

    test('writeTxn adds breadcrumb', () async {
      await fixture.sut.writeTxn(() async {});
      final breadcrumb = fixture.getCreatedBreadcrumb();
      verifyBreadcrumb('writeTxn', breadcrumb);
    });
  });

  group('add error breadcrumbs', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);

      when(fixture.isar.close()).thenAnswer((_) async {
        return true;
      });
      when(fixture.isar.name).thenReturn(Fixture.dbName);

      await fixture.setUp(injectMock: true);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing close adds error breadcrumb', () async {
      when(fixture.isar.close()).thenThrow(fixture.exception);
      try {
        await fixture.sut.close();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'close',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing clear adds error breadcrumb', () async {
      when(fixture.isar.clear()).thenThrow(fixture.exception);
      try {
        await fixture.sut.clear();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'clear',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing copyToFile adds error breadcrumb', () async {
      when(fixture.isar.copyToFile(any)).thenThrow(fixture.exception);
      try {
        await fixture.sut.copyToFile(fixture.copyPath);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'copyToFile',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing getSize adds error breadcrumb', () async {
      when(fixture.isar.getSize()).thenThrow(fixture.exception);
      try {
        await fixture.sut.getSize();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'getSize',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing txn adds error breadcrumb', () async {
      param() async {}
      when(fixture.isar.txn(param)).thenThrow(fixture.exception);
      try {
        await fixture.sut.txn(param);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'txn',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing writeTxn adds error breadcrumb', () async {
      param() async {}
      when(fixture.isar.writeTxn(param)).thenThrow(fixture.exception);
      try {
        await fixture.sut.writeTxn(param);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'writeTxn',
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
        fixture.options.sdk.integrations.contains('SentryIsarTracing'),
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
  final options = SentryOptions();
  final hub = MockHub();
  final isar = MockIsar();

  static final dbName = 'people-isar';
  final exception = Exception('fixture-exception');
  final copyPath = '${Directory.systemTemp.path}/copy';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late Isar sut;
  late final scope = Scope(options);

  Future<void> setUp({bool injectMock = false}) async {
    if (injectMock) {
      sut = SentryIsar(isar, hub);
    } else {
      // Make sure to use flutter test -j 1 to avoid tests running in parallel. This would break the automatic download.
      await Isar.initializeIsarCore(download: true);
      sut = await SentryIsar.open(
        [PersonSchema],
        directory: Directory.systemTemp.path,
        name: dbName,
        hub: hub,
      );
    }
    await deleteCopyPath();
  }

  Future<void> tearDown() async {
    try {
      // ignore: invalid_use_of_protected_member
      sut.requireOpen();
      await sut.close();
    } catch (_) {
      // Don't close  multiple times
    }
  }

  Isar getSut() {
    return sut;
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  Breadcrumb? getCreatedBreadcrumb() {
    return hub.scope.breadcrumbs.last;
  }

  Future<void> deleteCopyPath() async {
    final file = File(copyPath);
    if (await file.exists()) {
      await file.delete(recursive: true);
    }
  }
}
