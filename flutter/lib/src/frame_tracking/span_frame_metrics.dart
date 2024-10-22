import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

@internal
class SpanFrameMetricKey {
  final String data;
  final String measurement;

  SpanFrameMetricKey._(this.data) : measurement = data.replaceAll('.', '_');

  static final totalFrames = SpanFrameMetricKey._('frames.total');
  static final slowFrames = SpanFrameMetricKey._('frames.slow');
  static final frozenFrames = SpanFrameMetricKey._('frames.frozen');
  static final framesDelay = SpanFrameMetricKey._('frames.delay');

  static final allKeys = [
    totalFrames,
    slowFrames,
    frozenFrames,
    framesDelay,
  ];
}

@internal
class SpanFrameMetrics {
  final int totalFrameCount;
  final int slowFrameCount;
  final int frozenFrameCount;
  final int framesDelay;

  SpanFrameMetrics({
    required this.totalFrameCount,
    required this.slowFrameCount,
    required this.frozenFrameCount,
    required this.framesDelay,
  });

  void applyTo(ISentrySpan span) {
    final dataMap = {
      SpanFrameMetricKey.totalFrames: totalFrameCount,
      SpanFrameMetricKey.slowFrames: slowFrameCount,
      SpanFrameMetricKey.frozenFrames: frozenFrameCount,
      SpanFrameMetricKey.framesDelay: framesDelay,
    };

    _setData(span, dataMap);

    // If it's a root span, also apply measurements
    if (span is SentrySpan && span.isRootSpan) {
      // ignore: invalid_use_of_internal_member
      final tracer = span.tracer;

      _setData(tracer, dataMap);
      _setMeasurements(span, dataMap);
    }
  }

  void _setData(ISentrySpan span, Map<SpanFrameMetricKey, num> dataMap) {
    dataMap.forEach((metricKey, value) {
      span.setData(metricKey.data, value);
    });
  }

  void _setMeasurements(
      ISentrySpan span, Map<SpanFrameMetricKey, num> dataMap) {
    dataMap.forEach((metricKey, value) {
      span.setMeasurement(metricKey.measurement, value);
    });
  }
}
