import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';

// This file will contain observer definitions that are executed during
// specific points in the SDK such as as right before an event is sent.
// Only for internal use, e.g updating sessions only when an event is fully processed.

/// Called right before an event is sent, after all processing is complete.
/// Should not modify the event at this point.
@internal
abstract class BeforeSendEventObserver {
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint);
}
