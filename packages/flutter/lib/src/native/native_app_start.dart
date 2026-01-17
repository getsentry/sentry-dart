import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/type_safe_map_access.dart';

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
    // Convert appStartTime to int (iOS returns double, Android returns int)
    final appStartTime = json.getValueOrNull<int>('appStartTime');
    final pluginRegistrationTime =
        json.getValueOrNull<int>('pluginRegistrationTime');
    final isColdStart = json.getValueOrNull<bool>('isColdStart');
    final nativeSpanTimes =
        json.getValueOrNull<Map<dynamic, dynamic>>('nativeSpanTimes');

    if (appStartTime == null ||
        pluginRegistrationTime == null ||
        isColdStart == null ||
        nativeSpanTimes == null) {
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
