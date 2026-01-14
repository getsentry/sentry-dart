import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';
import 'package:test/test.dart';

import '../../mocks/mock_telemetry_buffer.dart';
import '../../test_utils.dart';

void main() {
  group('DefaultTelemetryProcessor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
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
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>();
        final processor = fixture.getSut(
          enableLogs: true,
          logBuffer: mockLogBuffer,
        );

        await processor.flush();

        expect(mockLogBuffer.flushCallCount, 1);
      });

      test('returns sync (null) when all buffers flush synchronously', () {
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>(asyncFlush: false);
        final processor = fixture.getSut(logBuffer: mockLogBuffer);
        processor.logBuffer = null;

        final result = processor.flush();

        expect(result, isNull);
      });

      test('returns Future when at least one buffer flushes asynchronously',
          () async {
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>(asyncFlush: true);
        final processor = fixture.getSut(logBuffer: mockLogBuffer);
        processor.logBuffer = null;

        final result = processor.flush();

        expect(result, isA<Future>());
        await result;
      });
    });
  });
}

class Fixture {
  late SentryOptions options;

  Fixture() {
    options = defaultTestOptions();
  }

  DefaultTelemetryProcessor getSut({
    bool enableLogs = false,
    MockTelemetryBuffer<SentryLog>? logBuffer,
  }) {
    options.enableLogs = enableLogs;
    return DefaultTelemetryProcessor(
      options.log,
      logBuffer: logBuffer,
    );
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
