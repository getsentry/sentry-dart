import 'dart:async';

import 'package:flutter/services.dart';

mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
