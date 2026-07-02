// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

@internal
enum AppStartType { cold, warm }

/// Source-agnostic app start timing data.
///
/// Produced by feeders such as the native parser; consumed by the app start
/// tracking pipeline independently of where the timings came from.
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
