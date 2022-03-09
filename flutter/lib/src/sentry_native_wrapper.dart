import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

/// Provide typed methods to access native layer.
@internal
class SentryNativeWrapper {
  SentryNativeWrapper(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  // TODO Move other native calls here.

  Future<NativeAppStart?> fetchNativeAppStart() async {
    try {
      final json = await _channel
          .invokeMapMethod<String, dynamic>('fetchNativeAppStart');
      return (json != null) ? NativeAppStart.fromJson(json) : null;
    } catch (error, stackTrace) {
      _options.logger(
        SentryLevel.warning,
        'Native call `fetchNativeAppStart` failed',
        exception: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<NativeFrames?> fetchNativeFrames() async {
    try {
      final json = await _channel
          .invokeMapMethod<String, dynamic>('fetchNativeFrames');
      return (json != null) ? NativeFrames.fromJson(json) : null;
    } catch (error, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Native call `fetchNativeFrames` failed',
        exception: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

class NativeAppStart {
  NativeAppStart(this.appStartTime, this.isColdStart);

  double appStartTime;
  bool isColdStart;

  factory NativeAppStart.fromJson(Map<String, dynamic> json) {
    return NativeAppStart(
      json['appStartTime'],
      json['isColdStart'],
    );
  }
}

class NativeFrames {
  NativeFrames(this.totalFrames, this.slowFrames, this.frozenFrames);

  int totalFrames;
  int slowFrames;
  int frozenFrames;

  factory NativeFrames.fromJson(Map<String, dynamic> json) {
    return NativeFrames(
      json['totalFrames'],
      json['slowFrames'],
      json['frozenFrames'],
    );
  }
}
