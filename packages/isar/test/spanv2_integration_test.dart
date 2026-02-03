// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library;

import 'dart:io';

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_isar/sentry_isar.dart';

import 'person.dart';
import 'utils.dart';

void main() {
  group('Isar SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('Collection.count() creates spanv2 with correct attributes', () async {
      final collection = fixture.isar.persons;

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      final count = await collection.count();

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      expect(count, equals(0));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('isar'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbName]?.value,
        equals('test-db'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
        equals('auto.db.isar.collection'),
      );

      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('Collection.put() creates spanv2', () async {
      final collection = fixture.isar.persons;

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      await fixture.isar.writeTxn(() async {
        await collection.put(Person()..name = 'John Doe');
      });

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final count = await collection.count();
      expect(count, equals(1));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('isar'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbName]?.value,
        equals('test-db'),
      );
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Collection.get() creates spanv2', () async {
      final collection = fixture.isar.persons;

      // Insert test data
      await fixture.isar.writeTxn(() async {
        await collection.put(Person()..name = 'Jane Doe');
      });

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      final person = await collection.get(1);

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      expect(person, isNotNull);
      expect(person!.name, equals('Jane Doe'));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('isar'),
      );
      expect(span.parentSpan, equals(transactionSpan));
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;
  late Isar isar;

  static const String dbName = 'test-db';

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..telemetryProcessor = processor;
    hub = Hub(options);

    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);
  }

  Future<void> setUp() async {
    // Open Isar database with Sentry wrapper
    final dir = Directory.systemTemp.createTempSync('isar_test_');
    isar = await SentryIsar.open(
      [PersonSchema],
      directory: dir.path,
      name: dbName,
      hub: hub,
    );
  }

  Future<void> tearDown() async {
    processor.clear();

    try {
      if (isar.isOpen) {
        await isar.close(deleteFromDisk: true);
      }
    } catch (e) {
      // Ignore errors during cleanup
    }

    await hub.close();
  }
}
