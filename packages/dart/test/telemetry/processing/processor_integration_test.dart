import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/telemetry/processing/in_memory_buffer.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';
import 'package:sentry/src/telemetry/processing/processor_integration.dart';
import 'package:test/test.dart';

import '../../mocks/mock_hub.dart';
import '../../mocks/mock_client_report_recorder.dart';
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

      test('oversized log records buffer overflow client report', () {
        final options = fixture.options;
        fixture.getSut().call(fixture.hub, options);

        final processor =
            options.telemetryProcessor as DefaultTelemetryProcessor;
        processor.addLog(fixture.createLog('x' * (1024 * 1024)));

        expect(fixture.transport.envelopes, isEmpty);

        final lostLog = fixture.recorder.lostLogs.single;
        expect(lostLog.reason, DiscardReason.bufferOverflow);
        expect(lostLog.count, 1);
        expect(lostLog.bytes, greaterThan(1024 * 1024));
      });

      test('oversized metric records buffer overflow client report', () {
        final options = fixture.options;
        fixture.getSut().call(fixture.hub, options);

        final processor =
            options.telemetryProcessor as DefaultTelemetryProcessor;
        processor.addMetric(
          fixture.createMetric(name: 'x' * (1024 * 1024)),
        );

        expect(fixture.transport.envelopes, isEmpty);

        final lostMetric = fixture.recorder.lostMetrics.single;
        expect(lostMetric.reason, DiscardReason.bufferOverflow);
        expect(lostMetric.count, 1);
        expect(lostMetric.bytes, greaterThan(1024 * 1024));
      });

      test('unencodable metric records internal SDK error client report', () {
        final options = fixture.options;
        fixture.getSut().call(fixture.hub, options);

        final processor =
            options.telemetryProcessor as DefaultTelemetryProcessor;
        processor.addMetric(fixture.createUnencodableMetric());

        expect(fixture.transport.envelopes, isEmpty);

        final lostMetric = fixture.recorder.lostMetrics.single;
        expect(lostMetric.reason, DiscardReason.internalSdkError);
        expect(lostMetric.count, 1);
        expect(lostMetric.bytes, isNull);
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

      for (final (sendDefaultPii, expectedSetting) in [
        (true, 'auto'),
        (false, 'never'),
      ]) {
        test(
            'span envelope ingest_settings is $expectedSetting '
            'when sendDefaultPii is $sendDefaultPii', () async {
          final options = fixture.options..sendDefaultPii = sendDefaultPii;
          fixture.getSut().call(fixture.hub, options);

          final processor =
              options.telemetryProcessor as DefaultTelemetryProcessor;
          final span = fixture.createSpan();
          span.end();
          processor.addSpan(span);
          await processor.flush();

          final payload = await decodeEnvelopeItemPayload(
              fixture.transport.envelopes.first);
          expect(payload['ingest_settings'], {
            'infer_ip': expectedSetting,
            'infer_user_agent': expectedSetting,
          });
        });
      }

      test('adds span replay_id attribute to envelope DSC', () async {
        final options = fixture.options;
        fixture.getSut().call(fixture.hub, options);

        final processor =
            options.telemetryProcessor as DefaultTelemetryProcessor;
        final span = fixture.createSpan()
          ..setAttribute(
            SemanticAttributesConstants.sentryReplayId,
            SentryAttribute.string('42'),
          );
        span.end();
        processor.addSpan(span);
        await processor.flush();

        expect(fixture.transport.envelopes.first.header.traceContext?.replayId,
            SentryId.fromId('42'));
      });

      test('adds span replay_id attribute to frozen envelope DSC', () async {
        final options = fixture.options;
        fixture.getSut().call(fixture.hub, options);

        final processor =
            options.telemetryProcessor as DefaultTelemetryProcessor;
        final span = fixture.createSpan();
        final dsc = span.resolveDsc();
        span.setAttribute(
          SemanticAttributesConstants.sentryReplayId,
          SentryAttribute.string('42'),
        );
        span.end();
        processor.addSpan(span);
        await processor.flush();

        expect(dsc.replayId, SentryId.fromId('42'));
        expect(fixture.transport.envelopes.first.header.traceContext?.replayId,
            SentryId.fromId('42'));
      });
    });
  });
}

class _Fixture {
  final hub = MockHub();
  final transport = MockTransport();
  final recorder = MockClientReportRecorder();
  late SentryOptions options;

  _Fixture() {
    options = defaultTestOptions()
      ..transport = transport
      ..recorder = recorder;
  }

  InMemoryTelemetryProcessorIntegration getSut() =>
      InMemoryTelemetryProcessorIntegration();

  SentryLog createLog([String body = 'test log']) {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: body,
      attributes: {},
    );
  }

  SentryMetric createMetric({String name = 'test metric', num value = 1}) {
    return SentryCounterMetric(
      timestamp: DateTime.now().toUtc(),
      traceId: SentryId.newId(),
      name: name,
      value: value,
    );
  }

  SentryMetric createUnencodableMetric() {
    return _UnencodableMetric(
      timestamp: DateTime.now().toUtc(),
      traceId: SentryId.newId(),
    );
  }

  RecordingSentrySpanV2 createSpan() {
    return RecordingSentrySpanV2.root(
      name: 'test-span',
      traceId: SentryId.newId(),
      onSpanEnd: (_) async {},
      clock: options.clock,
      dscCreator: (_) =>
          SentryTraceContextHeader(SentryId.newId(), 'publicKey'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );
  }
}

final class _UnencodableMetric extends SentryMetric {
  _UnencodableMetric({required super.timestamp, required super.traceId})
      : super(type: 'counter', name: 'test metric', value: 1);

  @override
  Map<String, dynamic> toJson() => throw StateError('Encoding failed');
}
