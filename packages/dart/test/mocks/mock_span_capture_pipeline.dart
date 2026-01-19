import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:sentry/src/telemetry/span/span_capture_pipeline.dart';

import '../test_utils.dart';

class FakeSpanCapturePipeline extends SpanCapturePipeline {
  FakeSpanCapturePipeline() : super(defaultTestOptions());

  SentrySpanV2? capturedSpan;
  Scope? capturedScope;

  @override
  Future<void> captureSpan(SentrySpanV2 span, Scope scope) async {
    capturedSpan = span;
    capturedScope = scope;
  }
}
