import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ExamplePluginWeb {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'example.flutter.sentry.io',
      const StandardMethodCodec(),
      registrar.messenger,
    );

    final pluginInstance = ExamplePluginWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    if (call.method == 'console.log') {
      await Sentry.captureMessage(call.toString());
    }
    return '';
  }
}
