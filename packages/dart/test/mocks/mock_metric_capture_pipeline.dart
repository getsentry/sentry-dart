import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/metric.dart';
import 'package:sentry/src/telemetry/metric/metric_capture_pipeline.dart';

import 'mock_sentry_client.dart';

class MockMetricCapturePipeline extends MetricCapturePipeline {
  MockMetricCapturePipeline(super.options);

  final List<CaptureMetricCall> captureMetricCalls = [];

  int get callCount => captureMetricCalls.length;

  @override
  Future<void> captureMetric(SentryMetric metric, {Scope? scope}) async {
    captureMetricCalls.add(CaptureMetricCall(metric, scope));
  }
}
