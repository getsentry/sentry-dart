// ignore_for_file: invalid_use_of_internal_member
// @TestOn('vm')
@TestOn('vm')

import 'dart:io';

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:hive/hive.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:test/test.dart';

import 'person.dart';
import 'utils.dart';

void main() {
  group('Hive SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('Box.get() creates spanv2 with correct attributes', () async {
      final box = fixture.box;

      // Add test data
      await box.put('test-key', Person('John Doe'));

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      final result = box.get('test-key');

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      expect(result, isNotNull);
      expect(result!.name, equals('John Doe'));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('flutter_hive'));
      expect(span.attributes[SemanticAttributesConstants.dbName]?.value, equals('test-box'));
      expect(span.attributes['sync']?.value, equals(true));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value, equals('auto.db.hive.box_base'));

      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('Box.put() creates spanv2', () async {
      final box = fixture.box;

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      await box.put('new-key', Person('Jane Doe'));

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('flutter_hive'));
      expect(span.attributes[SemanticAttributesConstants.dbName]?.value, equals('test-box'));
      expect(span.parentSpan, equals(transactionSpan));
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;
  late Box<Person> box;

  static const String boxName = 'test-box';

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
    // Initialize Hive with a temporary directory
    Hive.init(Directory.systemTemp.path);

    // Register the Person adapter if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PersonAdapter());
    }

    // Open box with Sentry wrapper
    SentryHive.setHub(hub);
    box = await SentryHive.openBox<Person>(boxName);
  }

  Future<void> tearDown() async {
    processor.clear();

    try {
      if (box.isOpen) {
        await box.deleteFromDisk();
        await box.close();
      }
      await Hive.close();
    } catch (e) {
      // Ignore errors during cleanup
    }

    await hub.close();
  }
}
