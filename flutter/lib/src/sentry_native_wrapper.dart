import 'package:flutter/services.dart';

import '../sentry_flutter.dart';

/// Provide typed methods to access native layer.
class SentryNativeWrapper {
  SentryNativeWrapper(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  // TODO Move other native calls here.

  Future<NativeAppStart?> fetchNativeAppStart() async {
    try {
      final json = await _channel.invokeMapMethod<String, dynamic>('fetchNativeAppStart');
      return (json != null) ? NativeAppStart.fromJson(json) : null;
    } catch (error, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Native call `fetchNativeAppStart` failed',
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class NativeAppStart {
  NativeAppStart(this.appStartTime, this.isColdStart, this.didFetchAppStart);

  double appStartTime;
  bool isColdStart;
  bool didFetchAppStart;

  factory NativeAppStart.fromJson(Map<String, dynamic> json) {
    return NativeAppStart(
      json['appStartTime'],
      json['isColdStart'],
      json['didFetchAppStart'],
    );
  }
}
