import 'package:meta/meta.dart';

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

  factory NativeAppStart.fromJson(Map<String, dynamic> json) {
    return NativeAppStart(
      appStartTime: json['appStartTime'] as double,
      pluginRegistrationTime: json['pluginRegistrationTime'] as int,
      isColdStart: json['isColdStart'] as bool,
      nativeSpanTimes: json['nativeSpanTimes'] as Map<dynamic, dynamic>,
    );
  }
}
