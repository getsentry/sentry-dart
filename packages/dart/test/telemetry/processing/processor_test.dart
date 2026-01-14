import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/sentry_metric.dart';
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

    group('addMetric', () {
      test('routes metric to metric buffer', () {
        final mockMetricBuffer = MockTelemetryBuffer<SentryMetric>();
        final processor =
            fixture.getSut(enableMetrics: true, metricBuffer: mockMetricBuffer);

        final metric = fixture.createMetric();
        processor.addMetric(metric);

        expect(mockMetricBuffer.addedItems.length, 1);
        expect(mockMetricBuffer.addedItems.first, metric);
      });

      test('does not throw when no metric buffer registered', () {
        final processor = fixture.getSut();
        processor.logBuffer = null;

        final log = fixture.createLog();
        processor.addLog(log);
      });
    });

    group('flush', () {
      test('flushes all registered buffers', () async {
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>();
        final mockMetricBuffer = MockTelemetryBuffer<SentryMetric>();

        final processor = fixture.getSut(
          enableLogs: true,
          logBuffer: mockLogBuffer,
          metricBuffer: mockMetricBuffer,
        );

        await processor.flush();

        expect(mockLogBuffer.flushCallCount, 1);
        expect(mockMetricBuffer.flushCallCount, 1);
      });

      test('returns sync (null) when all buffers flush synchronously', () {
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>(asyncFlush: false);
        final mockMetricBuffer =
            MockTelemetryBuffer<SentryMetric>(asyncFlush: false);

        final processor = fixture.getSut(
            logBuffer: mockLogBuffer, metricBuffer: mockMetricBuffer);

        final result = processor.flush();

        expect(result, isNull);
      });

      test('returns Future when at least one buffer flushes asynchronously',
          () async {
        final mockLogBuffer = MockTelemetryBuffer<SentryLog>(asyncFlush: true);
        final mockMetricBuffer =
            MockTelemetryBuffer<SentryMetric>(asyncFlush: false);
        final processor = fixture.getSut(
            logBuffer: mockLogBuffer, metricBuffer: mockMetricBuffer);

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
    bool enableMetrics = false,
    MockTelemetryBuffer<SentryLog>? logBuffer,
    MockTelemetryBuffer<SentryMetric>? metricBuffer,
  }) {
    options.enableLogs = enableLogs;
    options.enableMetrics = enableMetrics;
    return DefaultTelemetryProcessor(
        logBuffer: logBuffer, metricBuffer: metricBuffer);
  }

  SentryLog createLog({String body = 'test log'}) {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: body,
      attributes: {},
    );
  }

  SentryMetric createMetric() => SentryCounterMetric(
        timestamp: DateTime.now().toUtc(),
        attributes: {},
        name: 'test-metric',
        value: 1,
        traceId: SentryId.newId(),
      );
}
