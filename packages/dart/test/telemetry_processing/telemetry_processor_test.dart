import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/simple_span.dart';
import 'package:sentry/src/telemetry_processing/telemetry_processor.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';
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
        final mockSpanBuffer = MockTelemetryBuffer<Span>();
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);

        final span = fixture.createSpan();
        span.end();
        processor.addSpan(span);

        expect(mockSpanBuffer.addedItems.length, 1);
        expect(mockSpanBuffer.addedItems.first, span);
      });

      test('handles subtypes correctly (SimpleSpan -> Span buffer)', () {
        final mockSpanBuffer = MockTelemetryBuffer<Span>();
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);

        final simpleSpan = fixture.createSpan();
        simpleSpan.end();
        processor.addSpan(simpleSpan);

        expect(mockSpanBuffer.addedItems.length, 1);
        expect(mockSpanBuffer.addedItems.first, isA<SimpleSpan>());
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
        final mockSpanBuffer = MockTelemetryBuffer<Span>();
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
        final mockSpanBuffer = MockTelemetryBuffer<Span>();
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);
        processor.logBuffer = null;

        await processor.flush();

        expect(mockSpanBuffer.flushCallCount, 1);
      });

      test('returns sync (null) when all buffers flush synchronously', () {
        final mockSpanBuffer = MockTelemetryBuffer<Span>(asyncFlush: false);
        final processor = fixture.getSut(spanBuffer: mockSpanBuffer);
        processor.logBuffer = null;

        final result = processor.flush();

        expect(result, isNull);
      });

      test('returns Future when at least one buffer flushes asynchronously',
          () async {
        final mockSpanBuffer = MockTelemetryBuffer<Span>(asyncFlush: true);
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

  Fixture() {
    options = defaultTestOptions();
  }

  DefaultTelemetryProcessor getSut({
    bool enableLogs = false,
    MockTelemetryBuffer<Span>? spanBuffer,
    MockTelemetryBuffer<SentryLog>? logBuffer,
  }) {
    options.enableLogs = enableLogs;
    return DefaultTelemetryProcessor(
      options.log,
      spanBuffer: spanBuffer,
      logBuffer: logBuffer,
    );
  }

  SimpleSpan createSpan({String name = 'test-span'}) {
    return SimpleSpan(name: name, hub: hub);
  }

  SentryLog createLog({String body = 'test log'}) {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: body,
      attributes: {},
    );
  }
}
