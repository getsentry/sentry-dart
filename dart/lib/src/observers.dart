import 'dart:async';

import '../sentry.dart';

// This file will contain observer definitions that are executed during
// specific points in the SDK such as as right before an event is sent.

/// Called right before an event is sent, after all processing is complete.
/// Should not modify the event at this point.
abstract class BeforeSendEventObserver {
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint);
}
