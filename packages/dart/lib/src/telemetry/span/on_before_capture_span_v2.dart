import 'package:meta/meta.dart';

import '../../scope.dart';
import '../../sdk_lifecycle_hooks.dart';
import 'sentry_span_v2.dart';

/// Dispatched before a V2 span is captured and buffered.
///
/// Integrations can register callbacks to enrich the span with additional
/// attributes before it is sent to the telemetry processor.
///
/// This event is dispatched in [SentryClient.captureSpan] after the span
/// has ended but before the [beforeSendSpan] callback runs.
@internal
class OnBeforeCaptureSpanV2 extends SdkLifecycleEvent {
  OnBeforeCaptureSpanV2(this.span, this.scope);

  /// The span being captured. Callbacks can modify this span's attributes.
  final RecordingSentrySpanV2 span;

  /// The current scope, providing access to scope attributes, user info, etc.
  /// May be null if no scope was provided during capture.
  final Scope? scope;
}
