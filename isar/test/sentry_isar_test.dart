@TestOn('vm')

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_isar/sentry_isar.dart';
import 'package:sentry_isar/user.dart';

import 'package:sentry/src/sentry_tracer.dart';

import 'mocks/mocks.mocks.dart';

void main() {
  void verifySpan(
    String description,
    SentrySpan? span, {
    bool checkName = false,
  }) {
    expect(span?.context.operation, SentryIsar.dbOp);
    expect(span?.context.description, description);
    expect(span?.status, SpanStatus.ok());
    // ignore: invalid_use_of_internal_member
    expect(span?.origin, SentryTraceOrigins.autoDbIsar);
    // expect(span?.data[SentryHiveImpl.dbSystemKey], SentryHiveImpl.dbSystem);
    if (checkName) {
      expect(span?.data[SentryIsar.dbNameKey], Fixture.dbName);
    }
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

    test('open adds span', () async {
      final span = fixture.getCreatedSpan();
      verifySpan('open', span, checkName: true);
    });
  });
}

class Fixture {
  final options = SentryOptions();
  final hub = MockHub();

  static final dbName = 'people-isar';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late Isar sut;

  Future<void> setUp() async {
    // Make sure to use flutter test -j 1 to avoid tests running in parallel. This would break the automatic download.
    await Isar.initializeIsarCore(download: true);

    sut = await SentryIsar.open(
      [UserSchema],
      directory: Directory.systemTemp.path,
      name: dbName,
      hub: hub,
    );
  }

  Future<void> tearDown() async {
    await sut.close();
  }

  Isar getSut() {
    return sut;
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
