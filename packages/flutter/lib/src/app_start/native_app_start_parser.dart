import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import 'app_start_data.dart';

/// We filter out App starts more than 60s
@internal
const maxAppStartMillis = 60000;

/// Parses and validates native app start data.
///
/// Returns `null` if validation fails (e.g. >60s duration, missing setup time).
@internal
FinalizedAppStartData? parseNativeAppStart(
  NativeAppStart nativeAppStart,
  DateTime appStartEnd,
) {
  final sentrySetupStartDateTime = SentryFlutter.sentrySetupStartTime;
  if (sentrySetupStartDateTime == null) {
    return null;
  }

  final appStartDateTime =
      DateTime.fromMillisecondsSinceEpoch(nativeAppStart.appStartTime);
  final pluginRegistrationDateTime = DateTime.fromMillisecondsSinceEpoch(
      nativeAppStart.pluginRegistrationTime);

  final duration = appStartEnd.difference(appStartDateTime);

  // We filter out app start more than 60s.
  // This could be due to many different reasons.
  // If you do the manual init and init the SDK too late and it does not
  // compute the app start end in the very first Screen.
  // If the process starts but the App isn't in the foreground.
  // If the system forked the process earlier to accelerate the app start.
  // And some unknown reasons that could not be reproduced.
  // We've seen app starts with hours, days and even months.
  if (duration.inMilliseconds > maxAppStartMillis) {
    return null;
  }

  return FinalizedAppStartData(
    snapshot: AppStartData(
      type: nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
      processStartTimestamp: appStartDateTime,
      pluginRegistrationTimestamp: pluginRegistrationDateTime,
      sentrySetupTimestamp: sentrySetupStartDateTime,
      nativePhaseIntervals: parseNativeAppStartPhases(nativeAppStart),
    ),
    endTimestamp: appStartEnd,
  );
}
