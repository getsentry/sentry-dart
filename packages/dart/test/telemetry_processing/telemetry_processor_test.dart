import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/spans_v2/sentry_span_v2.dart';
import 'package:sentry/src/telemetry_processing/telemetry_processor.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';
import '../mocks/mock_sentry_span_v2_factory.dart';
import '../mocks/mock_telemetry_buffer.dart';
import '../test_utils.dart';

void main() {
  group('DefaultTelemetryProcessor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('addSpan', () {
      test('routes span to span buffer', () {
        final mockSpanBuffer = MockTelemetryBuffer<RecordingSentrySpanV2>();
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);

        final span = fixture.createSpan();
        span.end();
        processor.addSpan(span);

        expect(mockSpanBuffer.addedItems.length, 1);
        expect(mockSpanBuffer.addedItems.first, span);
      });

      test('does not throw when no span buffer registered', () {
        final processor = fixture.getSut();
        processor.spanBuffer = null;

        final span = fixture.createSpan();
        span.end();
        processor.addSpan(span);

        // Nothing to assert - just verifying no exception thrown
      });
    });

    group('addLog', () {
      test('routes log to log buffer', () {
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>();
        final processor =
            fixture.getSut(enableLogs: true, logBuffer: mockLogBuffer);

        final log = fixture.createLog();
        processor.addLog(log);

        expect(mockLogBuffer.addedItems.length, 1);
        expect(mockLogBuffer.addedItems.first, log);
      });

      test('does not throw when no log buffer registered', () {
        final processor = fixture.getSut();
        processor.logBuffer = null;

        final log = fixture.createLog();
        processor.addLog(log);
      });
    });

    group('flush', () {
      test('flushes all registered buffers', () async {
        final mockSpanBuffer = MockTelemetryBuffer<RecordingSentrySpanV2>();
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>();
        final processor = fixture.getSut(
          enableLogs: true,
          spanBuffer: mockSpanBuffer,
          logBuffer: mockLogBuffer,
        );

        await processor.flush();

        expect(mockSpanBuffer.flushCallCount, 1);
        expect(mockLogBuffer.flushCallCount, 1);
      });

      test('flushes only span buffer when log buffer is null', () async {
        final mockSpanBuffer = MockTelemetryBuffer<RecordingSentrySpanV2>();
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);
        processor.logBuffer = null;

        await processor.flush();

        expect(mockSpanBuffer.flushCallCount, 1);
      });

      test('returns sync (null) when all buffers flush synchronously', () {
        final mockSpanBuffer =
            MockTelemetryBuffer<RecordingSentrySpanV2>(asyncFlush: false);
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);
        processor.logBuffer = null;

        final result = processor.flush();

        expect(result, isNull);
      });

      test('returns Future when at least one buffer flushes asynchronously',
          () async {
        final mockSpanBuffer =
            MockTelemetryBuffer<RecordingSentrySpanV2>(asyncFlush: true);
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);
        processor.logBuffer = null;

        final result = processor.flush();

        expect(result, isA<Future>());
        await result;
      });
    });
  });
}

class Fixture {
  final hub = MockHub();

  late SentryOptions options;
  late MockSentrySpanV2Factory spanFactory;

  Fixture() {
    options = defaultTestOptions();
    spanFactory = MockSentrySpanV2Factory(options);
  }

  DefaultTelemetryProcessor getSut({
    bool enableLogs = false,
    MockTelemetryBuffer<RecordingSentrySpanV2>? spanBuffer,
    MockTelemetryBuffer<SentryLog>? logBuffer,
  }) {
    options.enableLogs = enableLogs;
    return DefaultTelemetryProcessor(
      options.log,
      spanBuffer: spanBuffer,
      logBuffer: logBuffer,
    );
  }

  RecordingSentrySpanV2 createSpan({
    RecordingSentrySpanV2? parent,
    String? name,
  }) =>
      spanFactory.createSpan(name: name, parent: parent);

  SentryLog createLog({String body = 'test log'}) {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: body,
      attributes: {},
    );
  }
}
