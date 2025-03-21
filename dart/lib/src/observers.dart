import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';

// This file will contain observer definitions that are executed during
// specific points in the SDK such as as right before an event is sent.
// Only for internal use, e.g updating sessions only when an event is fully processed.
// Not to be confused with the public callbacks such as beforeSend.
// These should not mutate the data that is passed through the observer.

/// Called right before an event is sent, after all processing is complete.
/// Should not modify the event at this point.
@internal
abstract class BeforeSendEventObserver {
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint);
}
