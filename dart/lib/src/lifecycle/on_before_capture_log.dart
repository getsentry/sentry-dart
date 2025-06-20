import 'package:meta/meta.dart';
import '../protocol/sentry_log.dart';
import '../sentry_client.dart';

@internal
class OnBeforeCaptureLog extends SdkLifecycleEvent {
  final SentryLog log;
  OnBeforeCaptureLog(this.log);
}
