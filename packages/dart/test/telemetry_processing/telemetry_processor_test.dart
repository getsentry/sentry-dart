import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/simple_span.dart';
import 'package:sentry/src/telemetry_processing/telemetry_buffer.dart';
import 'package:sentry/src/telemetry_processing/telemetry_processor.dart';
import 'package:test/test.dart';

import '../mocks/mock_buffer.dart';
import '../mocks/mock_hub.dart';
import '../test_utils.dart';

void main() {
  group('DefaultTelemetryProcessor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('initialization', () {
      test(
          'registers in-memory span buffer when traceLifeCycle is set to streaming',
          () {
        // TODO(next-pr): add test
      });

      test('registers in-memory log buffer when enableLogs is true', () {
        final processor = fixture.getSut(enableLogs: true);

        expect(processor.buffers[SentryLog], isA<InMemoryTelemetryBuffer>());
      });

      test('does NOT register log buffer when enableLogs is false', () {
        final processor = fixture.getSut(enableLogs: false);

        expect(processor.buffers.containsKey(SentryLog), isFalse);
      });
    });

    group('add', () {
      test('routes telemetry items to correct buffer', () {
        final processor = fixture.getSut();
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>();
        final mockSpanBuffer = MockTelemetryBuffer<Span>();
        processor.registerBuffer(mockLogBuffer);
        processor.registerBuffer(mockSpanBuffer);

        final log = fixture.createLog();
        processor.add(log);

        final span = fixture.createSpan();
        span.end();
        processor.add(span);

        expect(mockLogBuffer.addedItems.length, 1);
        expect(mockLogBuffer.addedItems.first, log);
        expect(mockSpanBuffer.addedItems.length, 1);
        expect(mockSpanBuffer.addedItems.first, span);
      });

      test('does not throw when no buffer registered for type', () {
        final processor = fixture.getSut();
        processor.buffers.clear();

        final log = fixture.createLog();
        processor.add(log);

        // Nothing to assert on - just verifying no exception thrown
      });

      // Note: Mismatch between buffer generic type and TelemetryType is now
      // impossible - the type is inferred from the generic parameter T.
    });

    group('flush', () {
      test('flushes all registered buffers', () async {
        final processor = fixture.getSut();
        final mockSpanBuffer = MockTelemetryBuffer<Span>();
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>();
        processor.registerBuffer(mockSpanBuffer);
        processor.registerBuffer(mockLogBuffer);

        await processor.flush();

        expect(mockSpanBuffer.flushCallCount, 1);
        expect(mockLogBuffer.flushCallCount, 1);
      });

      test('returns sync (null) when all buffers flush synchronously', () {
        final processor = fixture.getSut();
        final mockBuffer = MockTelemetryBuffer<Span>(asyncFlush: false);
        processor.registerBuffer(mockBuffer);

        final result = processor.flush();

        expect(result, isNull);
      });

      test('returns Future when at least one buffer flushes asynchronously',
          () async {
        final processor = fixture.getSut();
        final mockBuffer = MockTelemetryBuffer<Span>(asyncFlush: true);
        processor.registerBuffer(mockBuffer);

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

  DefaultTelemetryProcessor getSut({bool enableLogs = false}) {
    options.enableLogs = enableLogs;
    return DefaultTelemetryProcessor(options);
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
