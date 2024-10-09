import 'dart:ffi';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

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
    final pluginRegistrationTime = json['pluginRegistrationTime'];
    final isColdStart = json['isColdStart'];
    final nativeSpanTimes = json['nativeSpanTimes'];

    if (appStartTime is! double ||
        pluginRegistrationTime is! int ||
        isColdStart is! bool ||
        nativeSpanTimes is! Map) {
      // ignore: invalid_use_of_internal_member
      Sentry.currentHub.options.logger(
        SentryLevel.error,
        'Failed to parse json in NativeAppStart. Required keys are missing or have an invalid type',
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
