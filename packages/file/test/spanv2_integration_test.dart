// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')

import 'dart:io';

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_file/sentry_file.dart';
import 'package:test/test.dart';

import 'mock_sentry_client.dart';

void main() {
  group('File SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('File read creates spanv2 with correct attributes', () async {
      final file = File('test_resources/testfile.txt');
      final sut = fixture.getSut(file, sendDefaultPii: true);

      // Start transaction span (root of this trace)
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute file read operation
      final content = await sut.readAsString();

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify content was read
      expect(content, isNotEmpty);

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the file operation span
      final span = fixture.processor.findSpanByOperation('file.read');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify operation and attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('file.read'));
      expect(span.attributes['file.async']?.value, equals(true));
      expect(span.attributes['file.path']?.value, contains('testfile.txt'));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value, equals('auto.file'));

      // Verify parent-child relationship
      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('File write creates spanv2', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_write.txt');

      // Ensure temp file doesn't exist
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final sut = fixture.getSut(tempFile, sendDefaultPii: true);

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute file write operation
      await sut.writeAsString('Test content');

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify file was written
      expect(await tempFile.exists(), isTrue);
      expect(await tempFile.readAsString(), equals('Test content'));

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the file operation span
      final span = fixture.processor.findSpanByOperation('file.write');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify basic attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('file.write'));
      expect(span.attributes['file.async']?.value, equals(true));
      expect(span.attributes['file.path']?.value, contains('test_write.txt'));
      expect(span.parentSpan, equals(transactionSpan));

      // Cleanup
      await tempFile.delete();
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..telemetryProcessor = processor;
    hub = Hub(options);

    // Set up the span factory integration for streaming mode
    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);
  }

  SentryFile getSut(File file, {bool sendDefaultPii = false}) {
    options.sendDefaultPii = sendDefaultPii;
    return SentryFile(file, hub: hub);
  }

  Future<void> tearDown() async {
    processor.clear();
    await hub.close();
  }
}
