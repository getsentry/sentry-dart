import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class OnBeforeCaptureLog extends SdkLifecycleEvent {
  OnBeforeCaptureLog(this.log);

  final SentryLog log;
}

@internal
class OnBeforeSendEvent extends SdkLifecycleEvent {
  OnBeforeSendEvent(this.event);

  final SentryEvent event;
}
