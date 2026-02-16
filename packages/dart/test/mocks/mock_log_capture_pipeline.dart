import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/log/log_capture_pipeline.dart';

import 'mock_sentry_client.dart';

class MockLogCapturePipeline extends LogCapturePipeline {
  MockLogCapturePipeline(super.options);

  final List<CaptureLogCall> captureLogCalls = [];

  int get callCount => captureLogCalls.length;

  @override
  FutureOr<void> captureLog(SentryLog log, {Scope? scope}) async {
    captureLogCalls.add(CaptureLogCall(log, scope));
  }
}
