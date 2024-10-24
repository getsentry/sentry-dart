import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

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
    // If it's a root span, also apply measurements
    if (span is SentrySpan && span.isRootSpan) {
      // ignore: invalid_use_of_internal_member
      final tracer = span.tracer;

      _setData(tracer);

      final total = SentryMeasurement.totalFrames(totalFrameCount);
      final slow = SentryMeasurement.slowFrames(slowFrameCount);
      final frozen = SentryMeasurement.frozenFrames(frozenFrameCount);
      final delay = SentryMeasurement.framesDelay(framesDelay);

      span.setMeasurement(total.name, total.value);
      span.setMeasurement(slow.name, slow.value);
      span.setMeasurement(frozen.name, frozen.value);
      span.setMeasurement(delay.name, delay.value);
    } else {
      _setData(span);
    }
  }

  void _setData(ISentrySpan span) {
    span.setData(SpanDataConvention.totalFrames, totalFrameCount);
    span.setData(SpanDataConvention.slowFrames, slowFrameCount);
    span.setData(SpanDataConvention.frozenFrames, frozenFrameCount);
    span.setData(SpanDataConvention.framesDelay, framesDelay);
  }
}
