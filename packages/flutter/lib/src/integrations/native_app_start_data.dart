// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../utils/internal_logger.dart';

/// We filter out App starts more than 60s
@internal
const maxAppStartMillis = 60000;

@internal
enum AppStartType { cold, warm }

@internal
class AppStartInfo {
  AppStartInfo(
    this.type, {
    required this.start,
    required this.end,
    required this.pluginRegistration,
    required this.sentrySetupStart,
    required this.nativeSpanTimes,
  });

  final AppStartType type;
  final DateTime start;
  final DateTime end;
  final List<TimeSpan> nativeSpanTimes;

  final DateTime pluginRegistration;
  final DateTime sentrySetupStart;

  Duration get duration => end.difference(start);

  SentryMeasurement toMeasurement() {
    final duration = this.duration;
    return type == AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }

  String get appStartTypeOperation => 'app.start.${type.name}';

  String get appStartTypeDescription =>
      type == AppStartType.cold ? 'Cold Start' : 'Warm Start';
  final pluginRegistrationDescription = 'App start to plugin registration';
  final sentrySetupDescription = 'Before Sentry Init Setup';
  final firstFrameRenderDescription = 'First frame render';
}

@internal
class TimeSpan {
  TimeSpan({required this.start, required this.end, required this.description});

  final DateTime start;
  final DateTime end;
  final String description;
}

/// Parses and validates native app start data.
///
/// Returns `null` if validation fails (e.g. >60s duration, missing setup time).
@internal
AppStartInfo? parseNativeAppStart(
  NativeAppStart nativeAppStart,
  DateTime appStartEnd,
  SentryFlutterOptions options,
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

  List<TimeSpan> nativeSpanTimes = [];
  for (final entry in nativeAppStart.nativeSpanTimes.entries) {
    try {
      final startTimestampMs = entry.value['startTimestampMsSinceEpoch'] as int;
      final endTimestampMs = entry.value['stopTimestampMsSinceEpoch'] as int;
      nativeSpanTimes.add(TimeSpan(
        start: DateTime.fromMillisecondsSinceEpoch(startTimestampMs),
        end: DateTime.fromMillisecondsSinceEpoch(endTimestampMs),
        description: entry.key as String,
      ));
    } catch (e) {
      internalLogger.warning('Failed to parse native span times: $e');
      continue;
    }
  }

  // We want to sort because the native spans are not guaranteed to be in order.
  // Performance wise this won't affect us since the native span amount is very low.
  nativeSpanTimes.sort((a, b) => a.start.compareTo(b.start));

  return AppStartInfo(
    nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
    start: appStartDateTime,
    end: appStartEnd,
    pluginRegistration: pluginRegistrationDateTime,
    sentrySetupStart: sentrySetupStartDateTime,
    nativeSpanTimes: nativeSpanTimes,
  );
}
