import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_isar/sentry_isar.dart';
import 'package:sentry_isar/src/sentry_isar.dart';

import 'package:sentry/src/sentry_tracer.dart';

import 'mocks/mocks.mocks.dart';
import 'person.dart';

void main() {
  void verifySpan(
    String description,
    SentrySpan? span,
  ) {
    expect(span?.context.operation, SentryIsar.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbIsarCollection);
    expect(span?.data[SentryIsar.dbNameKey], Fixture.dbName);
    expect(span?.data[SentryIsar.dbCollectionKey], 'Person');
  }

  void verifyErrorSpan(String description, SentrySpan? span, Exception error) {
    expect(span?.context.operation, SentryIsar.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.internalError());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbIsarCollection);
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

    test('clear adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().clear();
      });
      final span = fixture.getCreatedSpan();
      verifySpan('clear', span);
    });

    test('count adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().count();
      });
      final span = fixture.getCreatedSpan();
      verifySpan('count', span);
    });

    test('delete adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().delete(0);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('delete', span);
    });

    test('deleteAll adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().deleteAll([0]);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('deleteAll', span);
    });

    test('deleteAllByIndex adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putByIndex('name', Person()..name = 'Joe');
        await fixture.getSut().deleteAllByIndex('name', []);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('deleteAllByIndex', span);
    });

    test('deleteByIndex adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putByIndex('name', Person()..name = 'Joe');
        await fixture.getSut().deleteByIndex('name', []);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('deleteByIndex', span);
    });

    test('get adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().get(1);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('get', span);
    });

    test('getAll adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getAll([1]);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('getAll', span);
    });

    test('getAllByIndex adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getAllByIndex('name', []);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('getAllByIndex', span);
    });

    test('getByIndex adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getByIndex('name', []);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('getByIndex', span);
    });

    test('getSize adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getSize();
      });
      final span = fixture.getCreatedSpan();
      verifySpan('getSize', span);
    });

    test('importJson adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().importJson([]);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('importJson', span);
    });

    test('importJsonRaw adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        final query = fixture.getSut().buildQuery<Person>();
        Uint8List jsonRaw = Uint8List.fromList([]);
        await query.exportJsonRaw((raw) {
          jsonRaw = Uint8List.fromList(raw);
        });
        await fixture.getSut().importJsonRaw(jsonRaw);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('importJsonRaw', span);
    });

    test('put adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().put(Person());
      });
      final span = fixture.getCreatedSpan();
      verifySpan('put', span);
    });

    test('putAll adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putAll([Person()]);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('putAll', span);
    });

    test('putAllByIndex adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putAllByIndex('name', [Person()]);
      });
      final span = fixture.getCreatedSpan();
      verifySpan('putAllByIndex', span);
    });

    test('putByIndex adds span', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putByIndex('name', Person());
      });
      final span = fixture.getCreatedSpan();
      verifySpan('putByIndex', span);
    });
  });

  group('add error spans', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);
      when(fixture.isarCollection.name).thenReturn(Fixture.dbCollection);

      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing clear adds error span', () async {
      when(fixture.isarCollection.clear()).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).clear();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('clear', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing count adds error span', () async {
      when(fixture.isarCollection.count()).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).count();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('count', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing delete adds error span', () async {
      when(fixture.isarCollection.delete(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).delete(0);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('delete', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing deleteAll adds error span', () async {
      when(fixture.isarCollection.deleteAll(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).deleteAll([0]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('deleteAll', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing deleteAllByIndex adds error span', () async {
      when(fixture.isarCollection.deleteAllByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).deleteAllByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'deleteAllByIndex',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing deleteByIndex adds error span', () async {
      when(fixture.isarCollection.deleteByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).deleteByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'deleteByIndex',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing get adds error span', () async {
      when(fixture.isarCollection.get(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).get(1);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('get', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing getAll adds error span', () async {
      when(fixture.isarCollection.getAll(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getAll([1]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('getAll', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing getAllByIndex adds error span', () async {
      when(fixture.isarCollection.getAllByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getAllByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'getAllByIndex',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing getByIndex adds error span', () async {
      when(fixture.isarCollection.getByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'getByIndex',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing getSize adds error span', () async {
      when(fixture.isarCollection.getSize()).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getSize();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('getSize', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing importJson adds error span', () async {
      when(fixture.isarCollection.importJson(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).importJson([]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'importJson',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing importJsonRaw adds error span', () async {
      when(fixture.isarCollection.importJsonRaw(any))
          .thenThrow(fixture.exception);
      try {
        await fixture
            .getSut(injectMock: true)
            .importJsonRaw(Uint8List.fromList([]));
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'importJsonRaw',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing put adds error span', () async {
      when(fixture.isarCollection.put(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).put(Person());
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('put', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing putAll adds error span', () async {
      when(fixture.isarCollection.putAll(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).putAll([Person()]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan('putAll', fixture.getCreatedSpan(), fixture.exception);
    });

    test('throwing putAllByIndex adds error span', () async {
      when(fixture.isarCollection.putAllByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture
            .getSut(injectMock: true)
            .putAllByIndex('name', [Person()]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'putAllByIndex',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });

    test('throwing putByIndex adds error span', () async {
      when(fixture.isarCollection.putByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).putByIndex('name', Person());
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyErrorSpan(
        'putByIndex',
        fixture.getCreatedSpan(),
        fixture.exception,
      );
    });
  });

  group('add breadcrumbs', () {
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

    test('clear adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().clear();
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('clear', breadcrumb);
    });

    test('count adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().count();
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('count', breadcrumb);
    });

    test('delete adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().delete(0);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('delete', breadcrumb);
    });

    test('deleteAll adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().deleteAll([0]);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('deleteAll', breadcrumb);
    });

    test('deleteAllByIndex adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putByIndex('name', Person()..name = 'Joe');
        await fixture.getSut().deleteAllByIndex('name', []);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[2];
      verifyBreadcrumb('deleteAllByIndex', breadcrumb);
    });

    test('deleteByIndex adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putByIndex('name', Person()..name = 'Joe');
        await fixture.getSut().deleteByIndex('name', []);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[2];
      verifyBreadcrumb('deleteByIndex', breadcrumb);
    });

    test('get adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().get(1);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('get', breadcrumb);
    });

    test('getAll adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getAll([1]);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('getAll', breadcrumb);
    });

    test('getAllByIndex adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getAllByIndex('name', []);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('getAllByIndex', breadcrumb);
    });

    test('getByIndex adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getByIndex('name', []);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('getByIndex', breadcrumb);
    });

    test('getSize adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().getSize();
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('getSize', breadcrumb);
    });

    test('importJson adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().importJson([]);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('importJson', breadcrumb);
    });

    test('importJsonRaw adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        final query = fixture.getSut().buildQuery<Person>();
        Uint8List jsonRaw = Uint8List.fromList([]);
        await query.exportJsonRaw((raw) {
          jsonRaw = Uint8List.fromList(raw);
        });
        await fixture.getSut().importJsonRaw(jsonRaw);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('importJsonRaw', breadcrumb);
    });

    test('put adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().put(Person());
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('put', breadcrumb);
    });

    test('putAll adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putAll([Person()]);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('putAll', breadcrumb);
    });

    test('putAllByIndex adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putAllByIndex('name', [Person()]);
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('putAllByIndex', breadcrumb);
    });

    test('putByIndex adds breadcrumb', () async {
      await fixture.sentryIsar.writeTxn(() async {
        await fixture.getSut().putByIndex('name', Person());
      });
      final breadcrumb = fixture.hub.scope.breadcrumbs[1];
      verifyBreadcrumb('putByIndex', breadcrumb);
    });
  });

  group('add error breadcrumbs', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
      when(fixture.hub.scope).thenReturn(fixture.scope);
      when(fixture.isarCollection.name).thenReturn(Fixture.dbCollection);

      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('throwing clear adds error breadcrumb', () async {
      when(fixture.isarCollection.clear()).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).clear();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'clear',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing count adds error breadcrumb', () async {
      when(fixture.isarCollection.count()).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).count();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'count',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing delete adds error breadcrumb', () async {
      when(fixture.isarCollection.delete(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).delete(0);
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
      when(fixture.isarCollection.deleteAll(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).deleteAll([0]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'deleteAll',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing deleteAllByIndex adds error breadcrumb', () async {
      when(fixture.isarCollection.deleteAllByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).deleteAllByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'deleteAllByIndex',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing deleteByIndex adds error breadcrumb', () async {
      when(fixture.isarCollection.deleteByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).deleteByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'deleteByIndex',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing get adds error breadcrumb', () async {
      when(fixture.isarCollection.get(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).get(1);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'get',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing getAll adds error breadcrumb', () async {
      when(fixture.isarCollection.getAll(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getAll([1]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'getAll',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing getAllByIndex adds error breadcrumb', () async {
      when(fixture.isarCollection.getAllByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getAllByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'getAllByIndex',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing getByIndex adds error breadcrumb', () async {
      when(fixture.isarCollection.getByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getByIndex('name', []);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'getByIndex',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing getSize adds error breadcrumb', () async {
      when(fixture.isarCollection.getSize()).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).getSize();
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'getSize',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing importJson adds error breadcrumb', () async {
      when(fixture.isarCollection.importJson(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).importJson([]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'importJson',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing importJsonRaw adds error breadcrumb', () async {
      when(fixture.isarCollection.importJsonRaw(any))
          .thenThrow(fixture.exception);
      try {
        await fixture
            .getSut(injectMock: true)
            .importJsonRaw(Uint8List.fromList([]));
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'importJsonRaw',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing put adds error breadcrumb', () async {
      when(fixture.isarCollection.put(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).put(Person());
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'put',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing putAll adds error breadcrumb', () async {
      when(fixture.isarCollection.putAll(any)).thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).putAll([Person()]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'putAll',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing putAllByIndex adds error breadcrumb', () async {
      when(fixture.isarCollection.putAllByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture
            .getSut(injectMock: true)
            .putAllByIndex('name', [Person()]);
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'putAllByIndex',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });

    test('throwing putByIndex adds error breadcrumb', () async {
      when(fixture.isarCollection.putByIndex(any, any))
          .thenThrow(fixture.exception);
      try {
        await fixture.getSut(injectMock: true).putByIndex('name', Person());
      } catch (error) {
        expect(error, fixture.exception);
      }
      verifyBreadcrumb(
        'putByIndex',
        fixture.getCreatedBreadcrumb(),
        status: 'internal_error',
      );
    });
  });
}

class Fixture {
  final options = SentryOptions();
  final hub = MockHub();
  final isarCollection = MockIsarCollection<Person>();

  static final dbName = 'people-isar';
  static final dbCollection = 'Person';
  final exception = Exception('fixture-exception');

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late Isar sentryIsar;
  late final scope = Scope(options);

  Future<void> setUp() async {
    // Make sure to use flutter test -j 1 to avoid tests running in parallel. This would break the automatic download.
    await Isar.initializeIsarCore(download: true);
    sentryIsar = await SentryIsar.open(
      [PersonSchema],
      directory: Directory.systemTemp.path,
      name: dbName,
      hub: hub,
    );
  }

  Future<void> tearDown() async {
    try {
      // ignore: invalid_use_of_protected_member
      sentryIsar.requireOpen();
      await sentryIsar.close();
    } catch (_) {
      // Don't close  multiple times
    }
  }

  IsarCollection<Person> getSut({bool injectMock = false}) {
    if (injectMock) {
      return SentryIsarCollection(isarCollection, hub, sentryIsar.name);
    } else {
      return sentryIsar.collection();
    }
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }

  Breadcrumb? getCreatedBreadcrumb() {
    return hub.scope.breadcrumbs.last;
  }
}
