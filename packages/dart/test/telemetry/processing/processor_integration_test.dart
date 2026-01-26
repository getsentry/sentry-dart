import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/processing/in_memory_buffer.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';
import 'package:sentry/src/telemetry/processing/processor_integration.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:test/test.dart';

import '../../mocks/mock_hub.dart';
import '../../mocks/mock_transport.dart';
import '../../test_utils.dart';

void main() {
  group('InMemoryTelemetryProcessorIntegration', () {
    late _Fixture fixture;

    setUp(() {
      fixture = _Fixture();
    });

    test(
        'sets up DefaultTelemetryProcessor when NoOpTelemetryProcessor is active',
        () {
      final options = fixture.options;
      expect(options.telemetryProcessor, isA<NoOpTelemetryProcessor>());

      fixture.getSut().call(fixture.hub, options);

      expect(options.telemetryProcessor, isA<DefaultTelemetryProcessor>());
    });

    test('does not override existing telemetry processor', () {
      final options = fixture.options;
      final existingProcessor = DefaultTelemetryProcessor();
      options.telemetryProcessor = existingProcessor;

      fixture.getSut().call(fixture.hub, options);

      expect(identical(options.telemetryProcessor, existingProcessor), isTrue);
    });

    test('adds integration name to SDK', () {
      final options = fixture.options;

      fixture.getSut().call(fixture.hub, options);

      expect(
        options.sdk.integrations,
        contains(InMemoryTelemetryProcessorIntegration.integrationName),
      );
    });

    test('configures log buffer as InMemoryTelemetryBuffer', () {
      final options = fixture.options;

      fixture.getSut().call(fixture.hub, options);

      final processor = options.telemetryProcessor as DefaultTelemetryProcessor;
      expect(processor.logBuffer, isA<InMemoryTelemetryBuffer<SentryLog>>());
    });

    test('configures span buffer as GroupedInMemoryTelemetryBuffer', () {
      final options = fixture.options;

      fixture.getSut().call(fixture.hub, options);

      final processor = options.telemetryProcessor as DefaultTelemetryProcessor;
      expect(processor.spanBuffer,
          isA<GroupedInMemoryTelemetryBuffer<RecordingSentrySpanV2>>());
    });

    test('configures span buffer with group key extractor', () {
      final options = fixture.options;

      final integration = fixture.getSut();
      integration.call(fixture.hub, options);

      final processor = options.telemetryProcessor as DefaultTelemetryProcessor;

      expect(
          (processor.spanBuffer
                  as GroupedInMemoryTelemetryBuffer<RecordingSentrySpanV2>)
              .groupKey,
          integration.spanGroupKeyExtractor);
    });

    test('spanGroupKeyExtractor uses traceId-spanId format', () {
      final options = fixture.options;

      final integration = fixture.getSut();
      integration.call(fixture.hub, options);

      final span = fixture.createSpan();
      final key = integration.spanGroupKeyExtractor(span);

      expect(key, '${span.traceId}-${span.spanId}');
    });
    group('flush', () {
      test('log reaches transport as envelope', () async {
        final options = fixture.options;
        fixture.getSut().call(fixture.hub, options);

        final processor =
            options.telemetryProcessor as DefaultTelemetryProcessor;
        processor.addLog(fixture.createLog());
        await processor.flush();

        expect(fixture.transport.envelopes, hasLength(1));
      });

      test('span reaches transport as envelope', () async {
        final options = fixture.options;
        fixture.getSut().call(fixture.hub, options);

        final processor =
            options.telemetryProcessor as DefaultTelemetryProcessor;
        final span = fixture.createSpan();
        span.end();
        processor.addSpan(span);
        await processor.flush();

        expect(fixture.transport.envelopes, hasLength(1));
      });
    });
  });
}

class _Fixture {
  final hub = MockHub();
  final transport = MockTransport();
  late SentryOptions options;

  _Fixture() {
    options = defaultTestOptions()..transport = transport;
  }

  InMemoryTelemetryProcessorIntegration getSut() =>
      InMemoryTelemetryProcessorIntegration();

  SentryLog createLog() {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'test log',
      attributes: {},
    );
  }

  RecordingSentrySpanV2 createSpan() {
    return RecordingSentrySpanV2.root(
      name: 'test-span',
      traceId: SentryId.newId(),
      onSpanEnd: (_) {},
      clock: options.clock,
      dscCreator: (_) =>
          SentryTraceContextHeader(SentryId.newId(), 'publicKey'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );
  }
}
