import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class NativeAppStart {
  NativeAppStart(
      {required this.appStartTime,
      required this.pluginRegistrationTime,
      required this.isColdStart,
      required this.nativeSpanTimes});

  int appStartTime;
  int pluginRegistrationTime;
  bool isColdStart;
  Map<dynamic, dynamic> nativeSpanTimes;

  static NativeAppStart? fromJson(Map<String, dynamic> json) {
    final appStartTimeValue = json['appStartTime'];
    final pluginRegistrationTime = json['pluginRegistrationTime'];
    final isColdStart = json['isColdStart'];
    final nativeSpanTimes = json['nativeSpanTimes'];

    // Convert appStartTime to int (iOS returns double, Android returns int)
    final int? appStartTime;
    if (appStartTimeValue is int) {
      appStartTime = appStartTimeValue;
    } else if (appStartTimeValue is double) {
      appStartTime = appStartTimeValue.toInt();
    } else {
      appStartTime = null;
    }

    if (appStartTime == null ||
        pluginRegistrationTime is! int ||
        isColdStart is! bool ||
        nativeSpanTimes is! Map) {
      // ignore: invalid_use_of_internal_member
      Sentry.currentHub.options.log(
        SentryLevel.warning,
        'Failed to parse json when capturing App Start metrics. App Start wont be reported.',
      );
      return null;
    }

    return NativeAppStart(
      appStartTime: appStartTime,
      pluginRegistrationTime: pluginRegistrationTime,
      isColdStart: isColdStart,
      nativeSpanTimes: nativeSpanTimes,
    );
  }
}
