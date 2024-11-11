import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
class NativeAppStart {
  NativeAppStart(
      {required this.appStartTime,
      required this.pluginRegistrationTime,
      required this.isColdStart,
      required this.nativeSpanTimes});

  double appStartTime;
  int pluginRegistrationTime;
  bool isColdStart;
  Map<dynamic, dynamic> nativeSpanTimes;

  static NativeAppStart? fromJson(Map<String, dynamic> json) {
    final appStartTime = json['appStartTime'];
    final appStartEndTime = json['appStartEndTime'];

    final pluginRegistrationTime = json['pluginRegistrationTime'];
    final isColdStart = json['isColdStart'];
    final nativeSpanTimes = json['nativeSpanTimes'];

    if (appStartTime is! double ||
        appStartEndTime is! int ||
        pluginRegistrationTime is! int ||
        isColdStart is! bool ||
        nativeSpanTimes is! Map) {
      // ignore: invalid_use_of_internal_member
      Sentry.currentHub.options.logger(
        SentryLevel.warning,
        'Failed to parse json when capturing App Start metrics. App Start wont be reported.',
      );
      return null;
    }

    print(
        'timing 1st: ${DateTime.fromMillisecondsSinceEpoch(appStartEndTime)}');

    return NativeAppStart(
      appStartTime: appStartTime,
      pluginRegistrationTime: pluginRegistrationTime,
      isColdStart: isColdStart,
      nativeSpanTimes: nativeSpanTimes,
    );
  }
}
