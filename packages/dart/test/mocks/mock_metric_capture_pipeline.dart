import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/metric.dart';
import 'package:sentry/src/telemetry/metric/metric_capture_pipeline.dart';

class FakeMetricCapturePipeline extends MetricCapturePipeline {
  FakeMetricCapturePipeline(super.options);

  int callCount = 0;
  SentryMetric? capturedMetric;
  Scope? capturedScope;

  @override
  Future<void> captureMetric(SentryMetric metric, {Scope? scope}) async {
    callCount++;
    capturedMetric = metric;
    capturedScope = scope;
  }
}
