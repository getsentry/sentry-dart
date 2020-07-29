import 'dart:async';

import 'package:flutter/services.dart';

class SentryFlutter {
  static const MethodChannel _channel = const MethodChannel('sentry_flutter');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
