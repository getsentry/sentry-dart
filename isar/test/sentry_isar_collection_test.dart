import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
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

  group('add spans', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

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
}

class Fixture {
  final options = SentryOptions();
  final hub = MockHub();
  final isar = MockIsar();

  static final dbName = 'people-isar';
  final exception = Exception('fixture-exception');

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late Isar sentryIsar;

  Future<void> setUp({bool injectMock = false}) async {
    if (injectMock) {
      sentryIsar = SentryIsar(isar, hub);
    } else {
      // Make sure to use flutter test -j 1 to avoid tests running in parallel. This would break the automatic download.
      await Isar.initializeIsarCore(download: true);
      sentryIsar = await SentryIsar.open(
        [PersonSchema],
        directory: Directory.systemTemp.path,
        name: dbName,
        hub: hub,
      );
    }
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

  IsarCollection<Person> getSut() {
    return sentryIsar.collection();
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
